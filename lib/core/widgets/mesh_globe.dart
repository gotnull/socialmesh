import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import '../../models/mesh_models.dart';
import '../theme.dart';

/// 3D Interactive Globe widget showing mesh node positions
/// Inspired by Stripe's globe and COBE library
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

  /// Initial phi angle (horizontal rotation) in radians
  final double initialPhi;

  /// Initial theta angle (vertical tilt) in radians
  final double initialTheta;

  /// Globe base color
  final Color baseColor;

  /// Dot color for landmass
  final Color dotColor;

  /// Marker color (default if not specified per marker)
  final Color markerColor;

  /// Connection line color
  final Color connectionColor;

  /// Whether to show the glow effect (disabled by default - custom shaders can cause issues)
  final bool showGlow;

  /// Number of dots to sample for the landmass pattern
  final int dotSamples;

  const MeshGlobe({
    super.key,
    this.nodes = const [],
    this.showConnections = true,
    this.onNodeSelected,
    this.autoRotateSpeed = 0.2,
    this.enabled = true,
    this.initialPhi = 0.0,
    this.initialTheta = 0.3,
    this.baseColor = const Color(0xFF1a1a2e),
    this.dotColor = const Color(0xFF4a4a6a),
    this.markerColor = const Color(0xFF42A5F5),
    this.connectionColor = const Color(0xFF42A5F5),
    this.showGlow = false,
    this.dotSamples = 8000,
  });

  @override
  State<MeshGlobe> createState() => MeshGlobeState();
}

class MeshGlobeState extends State<MeshGlobe> {
  late three.ThreeJS threeJs;
  bool _isInitialized = false;
  bool _hasError = false;

  // Globe parameters
  static const double _globeRadius = 2.0;
  static const double _markerSize = 0.08;
  static const double _markerHeight = 0.15;

  // Rotation state
  double _phi = 0.0;
  double _theta = 0.3;
  double _targetPhi = 0.0;
  double _targetTheta = 0.3;

  // Drag interaction
  bool _isDragging = false;
  Offset _lastDragPosition = Offset.zero;
  double _dragVelocityX = 0.0;
  double _dragVelocityY = 0.0;

  // Groups for organization
  three.Group? _globeGroup;
  three.Group? _markersGroup;
  three.Group? _connectionsGroup;
  three.Group? _dotsGroup;

  // For raycasting/selection
  final List<_MarkerMeshData> _markerMeshes = [];

  @override
  void initState() {
    super.initState();
    _phi = widget.initialPhi;
    _theta = widget.initialTheta;
    _targetPhi = _phi;
    _targetTheta = _theta;

    if (widget.enabled) {
      _initThreeJS();
    }
  }

  @override
  void didUpdateWidget(MeshGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled && !_isInitialized) {
        _initThreeJS();
      }
    }

    // Update markers if changed
    if (_isInitialized &&
        (widget.nodes != oldWidget.nodes ||
            widget.showConnections != oldWidget.showConnections)) {
      _updateMarkers();
      _updateConnections();
    }
  }

  void _initThreeJS() {
    debugPrint('MeshGlobe: Initializing ThreeJS...');
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        debugPrint('MeshGlobe: Setup complete, mounted=$mounted');
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      },
      setup: _setup,
      settings: three.Settings(
        clearColor: AppTheme.darkBackground.toARGB32(),
        enableShadowMap: false,
        antialias: true,
        alpha: true,
      ),
    );
  }

  @override
  void dispose() {
    if (_isInitialized) {
      threeJs.dispose();
    }
    super.dispose();
  }

  Future<void> _setup() async {
    debugPrint('MeshGlobe: Starting setup...');
    try {
      // Scene
      threeJs.scene = three.Scene();
      threeJs.scene.background = three.Color.fromHex32(
        AppTheme.darkBackground.toARGB32(),
      );

      // Camera
      threeJs.camera = three.PerspectiveCamera(
        45,
        threeJs.width / threeJs.height,
        0.1,
        100,
      );
      threeJs.camera.position.setValues(0, 0, 6);
      threeJs.camera.lookAt(three.Vector3(0, 0, 0));

      // Create globe group for rotation
      _globeGroup = three.Group();
      threeJs.scene.add(_globeGroup!);

      // Add ambient light
      final ambient = three.AmbientLight(0xffffff, 0.6);
      threeJs.scene.add(ambient);

      // Add directional light
      final directional = three.DirectionalLight(0xffffff, 0.8);
      directional.position.setValues(5, 3, 5);
      threeJs.scene.add(directional);

      // Create globe sphere (ocean/base)
      _createGlobeSphere();

      // Create dot pattern for landmass
      _createDotPattern();

      // Create markers group
      _markersGroup = three.Group();
      _globeGroup!.add(_markersGroup!);
      _updateMarkers();

      // Create connections group
      _connectionsGroup = three.Group();
      _globeGroup!.add(_connectionsGroup!);
      _updateConnections();

      // Add glow effect
      if (widget.showGlow) {
        _createGlow();
      }

      // Animation loop
      threeJs.addAnimationEvent((dt) {
        _animate(dt);
      });

      debugPrint('MeshGlobe: Setup completed successfully');
    } catch (e, stackTrace) {
      debugPrint('MeshGlobe setup error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _createGlobeSphere() {
    // Create the main globe sphere
    final geometry = three.SphereGeometry(_globeRadius, 64, 64);

    final material = three.MeshPhongMaterial.fromMap({
      'color': widget.baseColor.toARGB32() & 0xFFFFFF,
      'transparent': true,
      'opacity': 0.95,
      'shininess': 5,
    });

    final sphere = three.Mesh(geometry, material);
    _globeGroup!.add(sphere);
  }

  void _createDotPattern() {
    // Create dots using sunflower pattern (Fibonacci lattice)
    // Similar to COBE's approach for uniform sphere distribution
    _dotsGroup = three.Group();

    final dotGeometry = three.SphereGeometry(0.015, 6, 6);
    final dotMaterial = three.MeshBasicMaterial.fromMap({
      'color': widget.dotColor.toARGB32() & 0xFFFFFF,
    });

    // Golden angle in radians (pi * (3 - sqrt(5)))
    final goldenAngle = math.pi * (3 - math.sqrt(5));

    for (int i = 0; i < widget.dotSamples; i++) {
      // Sunflower/Fibonacci pattern for uniform distribution
      final y = 1 - (i / (widget.dotSamples - 1)) * 2; // -1 to 1
      final radiusAtY = math.sqrt(1 - y * y);
      final theta = goldenAngle * i;

      final x = math.cos(theta) * radiusAtY;
      final z = math.sin(theta) * radiusAtY;

      // Convert to lat/long to check if it's on land
      final lat = math.asin(y) * 180 / math.pi;
      final lon = math.atan2(z, x) * 180 / math.pi;

      // Simple land mask - show dots for major landmasses
      // This is a simplified approximation
      if (_isLand(lat, lon)) {
        final dot = three.Mesh(dotGeometry, dotMaterial);
        dot.position.setValues(
          x * (_globeRadius + 0.01),
          y * (_globeRadius + 0.01),
          z * (_globeRadius + 0.01),
        );
        _dotsGroup!.add(dot);
      }
    }

    _globeGroup!.add(_dotsGroup!);
  }

  /// Simple land detection (approximate bounding boxes for continents)
  bool _isLand(double lat, double lon) {
    // North America
    if (lat > 15 && lat < 72 && lon > -170 && lon < -50) return true;
    // South America
    if (lat > -56 && lat < 15 && lon > -82 && lon < -34) return true;
    // Europe
    if (lat > 35 && lat < 72 && lon > -10 && lon < 40) return true;
    // Africa
    if (lat > -35 && lat < 37 && lon > -18 && lon < 52) return true;
    // Asia
    if (lat > 5 && lat < 77 && lon > 40 && lon < 180) return true;
    if (lat > 5 && lat < 77 && lon > -180 && lon < -170) return true; // Wrap
    // Australia
    if (lat > -45 && lat < -10 && lon > 112 && lon < 155) return true;
    // Antarctica (minimal)
    if (lat < -60) return true;

    return false;
  }

  void _createGlow() {
    // Create a glow effect around the globe
    final glowGeometry = three.SphereGeometry(_globeRadius * 1.15, 32, 32);
    final glowMaterial = three.ShaderMaterial.fromMap({
      'uniforms': {
        'glowColor': {'value': three.Color.fromHex32(0xFF42A5F5)},
        'viewVector': {'value': threeJs.camera.position},
      },
      'vertexShader': '''
        varying vec3 vNormal;
        void main() {
          vNormal = normalize(normalMatrix * normal);
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      ''',
      'fragmentShader': '''
        varying vec3 vNormal;
        void main() {
          float intensity = pow(0.6 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 2.0);
          gl_FragColor = vec4(0.26, 0.65, 0.96, 1.0) * intensity * 0.3;
        }
      ''',
      'side': three.BackSide,
      'blending': three.AdditiveBlending,
      'transparent': true,
    });

    final glow = three.Mesh(glowGeometry, glowMaterial);
    threeJs.scene.add(glow);
  }

  void _updateMarkers() {
    if (_markersGroup == null) return;

    // Clear existing markers
    while (_markersGroup!.children.isNotEmpty) {
      _markersGroup!.remove(_markersGroup!.children.first);
    }
    _markerMeshes.clear();

    // Create new markers for nodes with position data
    for (final node in widget.nodes) {
      if (node.hasPosition) {
        _createMarker(node);
      }
    }
  }

  void _createMarker(MeshNode node) {
    // Convert lat/long to 3D position on sphere
    final pos = _latLongToPosition(node.latitude!, node.longitude!);

    // Create marker pin
    final pinGeometry = three.CylinderGeometry(
      _markerSize * 0.3, // top radius
      _markerSize * 0.1, // bottom radius
      _markerHeight,
      8,
    );

    final color = (node.avatarColor ?? 0xFF42A5F5) & 0xFFFFFF;
    final pinMaterial = three.MeshPhongMaterial.fromMap({
      'color': color,
      'emissive': node.isOnline ? (color & 0x333333) : 0x000000,
    });

    final pin = three.Mesh(pinGeometry, pinMaterial);

    // Create head (sphere on top)
    final headGeometry = three.SphereGeometry(_markerSize * 0.5, 12, 12);
    final headMaterial = three.MeshPhongMaterial.fromMap({
      'color': color,
      'emissive': node.isOnline ? (color & 0x444444) : 0x000000,
    });

    final head = three.Mesh(headGeometry, headMaterial);
    head.position.y = _markerHeight / 2 + _markerSize * 0.3;

    // Create group for the marker
    final markerGroup = three.Group();
    markerGroup.add(pin);
    markerGroup.add(head);

    // Position on globe surface
    markerGroup.position.setFrom(pos);

    // Orient marker to point outward from globe center
    markerGroup.lookAt(three.Vector3(0, 0, 0));
    markerGroup.rotateX(math.pi / 2);

    _markersGroup!.add(markerGroup);

    // Store for raycasting
    _markerMeshes.add(
      _MarkerMeshData(node: node, mesh: head, group: markerGroup),
    );
  }

  void _updateConnections() {
    if (_connectionsGroup == null) return;

    // Clear existing connections
    while (_connectionsGroup!.children.isNotEmpty) {
      _connectionsGroup!.remove(_connectionsGroup!.children.first);
    }

    if (!widget.showConnections) return;

    // Create connections between all nodes with position
    final nodesWithPos = widget.nodes.where((n) => n.hasPosition).toList();
    for (int i = 0; i < nodesWithPos.length - 1; i++) {
      for (int j = i + 1; j < nodesWithPos.length; j++) {
        _createConnection(nodesWithPos[i], nodesWithPos[j]);
      }
    }
  }

  void _createConnection(MeshNode from, MeshNode to) {
    // Get 3D positions
    final fromPos = _latLongToPosition(from.latitude!, from.longitude!);
    final toPos = _latLongToPosition(to.latitude!, to.longitude!);

    // Create arc curve between points
    final points = _createArcPoints(fromPos, toPos, 32);

    final geometry = three.BufferGeometry();
    final positions = <double>[];
    for (final point in points) {
      positions.addAll([point.x, point.y, point.z]);
    }
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(positions, 3),
    );

    final material = three.LineBasicMaterial.fromMap({
      'color': widget.connectionColor.toARGB32() & 0xFFFFFF,
      'transparent': true,
      'opacity': 0.6,
    });

    final line = three.Line(geometry, material);
    _connectionsGroup!.add(line);
  }

  List<three.Vector3> _createArcPoints(
    three.Vector3 from,
    three.Vector3 to,
    int segments,
  ) {
    final points = <three.Vector3>[];

    // Calculate midpoint and raise it above the sphere
    final mid = from.clone()..add(to);
    mid.scale(0.5);

    // Calculate arc height based on distance
    final distance = from.distanceTo(to);
    final arcHeight = 0.1 + distance * 0.15;

    // Normalize and scale to arc height
    mid.normalize();
    mid.scale(_globeRadius + arcHeight);

    // Create quadratic bezier curve
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final oneMinusT = 1 - t;

      // Quadratic bezier: (1-t)²*P0 + 2*(1-t)*t*P1 + t²*P2
      final point = three.Vector3();
      point.x =
          oneMinusT * oneMinusT * from.x +
          2 * oneMinusT * t * mid.x +
          t * t * to.x;
      point.y =
          oneMinusT * oneMinusT * from.y +
          2 * oneMinusT * t * mid.y +
          t * t * to.y;
      point.z =
          oneMinusT * oneMinusT * from.z +
          2 * oneMinusT * t * mid.z +
          t * t * to.z;

      points.add(point);
    }

    return points;
  }

  three.Vector3 _latLongToPosition(double lat, double lon) {
    // Convert lat/long (degrees) to 3D position on sphere
    final phi = (90 - lat) * math.pi / 180;
    final theta = (lon + 180) * math.pi / 180;

    final x = -_globeRadius * math.sin(phi) * math.cos(theta);
    final y = _globeRadius * math.cos(phi);
    final z = _globeRadius * math.sin(phi) * math.sin(theta);

    return three.Vector3(x, y, z);
  }

  void _animate(double dt) {
    if (_globeGroup == null) return;

    // Apply drag momentum
    if (!_isDragging) {
      // Apply velocity with friction
      _phi += _dragVelocityX * dt;
      _theta += _dragVelocityY * dt;

      // Apply friction
      _dragVelocityX *= 0.95;
      _dragVelocityY *= 0.95;

      // Auto-rotate when not dragging and velocity is low
      if (_dragVelocityX.abs() < 0.1 && _dragVelocityY.abs() < 0.1) {
        if (widget.autoRotateSpeed > 0) {
          _phi += dt * widget.autoRotateSpeed;
        }
      }

      // Animate toward target (for programmatic rotation)
      final phiDiff = _targetPhi - _phi;
      final thetaDiff = _targetTheta - _theta;
      if (phiDiff.abs() > 0.01 || thetaDiff.abs() > 0.01) {
        _phi += phiDiff * 0.1;
        _theta += thetaDiff * 0.1;
      }
    }

    // Clamp theta to avoid flipping
    _theta = _theta.clamp(-math.pi / 2 + 0.1, math.pi / 2 - 0.1);

    // Apply rotation to globe group
    _globeGroup!.rotation.y = _phi;
    _globeGroup!.rotation.x = _theta;
  }

  /// Rotate the globe to focus on a specific location
  void rotateToLocation(double lat, double lon, {bool animate = true}) {
    // Convert lat/long to rotation angles
    final targetPhi = -lon * math.pi / 180;
    final targetTheta = lat * math.pi / 180;

    if (animate) {
      _targetPhi = targetPhi;
      _targetTheta = targetTheta;
    } else {
      _phi = targetPhi;
      _theta = targetTheta;
      _targetPhi = targetPhi;
      _targetTheta = targetTheta;
    }

    // Stop any current momentum
    _dragVelocityX = 0;
    _dragVelocityY = 0;
  }

  /// Rotate to focus on a specific node
  void rotateToNode(MeshNode node, {bool animate = true}) {
    if (node.hasPosition) {
      rotateToLocation(node.latitude!, node.longitude!, animate: animate);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _lastDragPosition = details.localPosition;
    _dragVelocityX = 0;
    _dragVelocityY = 0;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final delta = details.localPosition - _lastDragPosition;
    _lastDragPosition = details.localPosition;

    // Convert screen delta to rotation
    const sensitivity = 0.005;
    _phi += delta.dx * sensitivity;
    _theta -= delta.dy * sensitivity;

    // Store velocity for momentum
    _dragVelocityX = delta.dx * sensitivity * 60;
    _dragVelocityY = -delta.dy * sensitivity * 60;

    // Update targets
    _targetPhi = _phi;
    _targetTheta = _theta;
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isInitialized || _markerMeshes.isEmpty) return;

    // Get the tap position in normalized device coordinates (-1 to +1)
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final localPosition = details.localPosition;

    // Convert to normalized device coordinates
    final x = (localPosition.dx / size.width) * 2 - 1;
    final y = -(localPosition.dy / size.height) * 2 + 1;

    // Create raycaster
    final raycaster = three.Raycaster();
    final mouse = three.Vector2(x, y);

    // Set ray from camera through mouse position
    raycaster.setFromCamera(mouse, threeJs.camera);

    // Collect all marker head meshes for intersection testing
    final meshes = _markerMeshes.map((m) => m.mesh).toList();

    // Check for intersections
    final intersects = raycaster.intersectObjects(meshes, false);

    if (intersects.isNotEmpty) {
      // Find which marker was hit
      final hitMesh = intersects.first.object;
      final markerData = _markerMeshes.firstWhere(
        (m) => m.mesh == hitMesh,
        orElse: () => _markerMeshes.first,
      );

      widget.onNodeSelected?.call(markerData.node);
      return;
    }

    // Fallback: If no direct hit, find the closest marker to the tap
    // by projecting marker positions to screen space
    _selectClosestMarkerToTap(localPosition, size);
  }

  /// Select the closest marker to a tap position using screen-space projection
  void _selectClosestMarkerToTap(Offset tapPosition, Size screenSize) {
    if (_markerMeshes.isEmpty || _globeGroup == null) return;

    MeshNode? closestNode;
    double closestDistance = double.infinity;

    // Threshold in screen pixels for tap tolerance
    const tapThreshold = 50.0;

    for (final markerData in _markerMeshes) {
      // Get world position of the marker
      final worldPos = three.Vector3();
      markerData.group.getWorldPosition(worldPos);

      // Project to screen coordinates
      final screenPos = worldPos.clone();
      screenPos.project(threeJs.camera);

      // Convert from NDC (-1 to 1) to screen pixels
      final screenX = (screenPos.x + 1) / 2 * screenSize.width;
      final screenY = (-screenPos.y + 1) / 2 * screenSize.height;

      // Check if marker is in front of camera (z < 1 in NDC)
      if (screenPos.z > 1) continue;

      // Calculate distance from tap to projected marker position
      final dx = tapPosition.dx - screenX;
      final dy = tapPosition.dy - screenY;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance < closestDistance && distance < tapThreshold) {
        closestDistance = distance;
        closestNode = markerData.node;
      }
    }

    if (closestNode != null) {
      widget.onNodeSelected?.call(closestNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    if (_hasError) {
      return Container(
        color: AppTheme.darkBackground,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_off, size: 48, color: AppTheme.textTertiary),
              SizedBox(height: 8),
              Text(
                'Globe unavailable',
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    // Always return threeJs.build() - it needs to be in the widget tree to initialize
    // The loading indicator is shown as an overlay until setup completes
    return GestureDetector(
      onPanStart: _isInitialized ? _handlePanStart : null,
      onPanUpdate: _isInitialized ? _handlePanUpdate : null,
      onPanEnd: _isInitialized ? _handlePanEnd : null,
      onTapUp: _isInitialized ? _handleTapUp : null,
      child: Stack(
        children: [
          Container(color: AppTheme.darkBackground, child: threeJs.build()),
          if (!_isInitialized) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

/// Internal class to track marker meshes for raycasting
class _MarkerMeshData {
  final MeshNode node;
  final three.Mesh mesh;
  final three.Group group;

  _MarkerMeshData({
    required this.node,
    required this.mesh,
    required this.group,
  });
}
