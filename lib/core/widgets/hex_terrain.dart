import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import '../theme.dart';

/// 3D Hexagonal terrain widget inspired by HexTerrain
/// Uses three_js for WebGL rendering
class HexTerrain extends StatefulWidget {
  /// Auto-rotate speed (0 to disable)
  final double autoRotateSpeed;

  /// Whether to show the terrain
  final bool enabled;

  const HexTerrain({
    super.key,
    this.autoRotateSpeed = 0.6,
    this.enabled = true,
  });

  @override
  State<HexTerrain> createState() => _HexTerrainState();
}

class _HexTerrainState extends State<HexTerrain> {
  late three.ThreeJS threeJs;
  bool _isInitialized = false;
  bool _hasError = false;

  // Terrain parameters - adjusted for proper HexTerrain look
  static const int _terrainRadius = 25;
  static const double _hexSize = 0.4;
  static const double _heightScale = 3.0; // Height multiplier for terrain

  // Biome colors (matching HexTerrain exactly)
  static const _waterColor = 0xFF4AA3DF; // Bright cyan-blue water
  static const _shoreColor = 0xFF6BBFEF; // Light blue shore
  static const _beachColor = 0xFFE8D4A8; // Sandy beige
  static const _shrubColor = 0xFFB8C84A; // Yellow-green grass
  static const _forestColor = 0xFF5A8A3A; // Medium green
  static const _darkForestColor = 0xFF2A5A2A; // Dark forest green
  static const _stoneColor = 0xFF8A8A7A; // Gray stone
  static const _snowColor = 0xFFEEEEEE; // White snow

  // Water level threshold
  static const double _waterLevel = 0.15;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _initThreeJS();
    }
  }

  void _initThreeJS() {
    threeJs = three.ThreeJS(
      onSetupComplete: () {
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      },
      setup: _setup,
      settings: three.Settings(
        clearColor: AppTheme.darkBackground.toARGB32(),
        enableShadowMap: true,
        shadowMapType: three.PCFSoftShadowMap,
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
    try {
      // Scene
      threeJs.scene = three.Scene();
      threeJs.scene.background = three.Color.fromHex32(
        AppTheme.darkBackground.toARGB32(),
      );

      // Camera - positioned above looking down at terrain (like HexTerrain)
      threeJs.camera = three.PerspectiveCamera(
        50,
        threeJs.width / threeJs.height,
        0.1,
        1000,
      );
      threeJs.camera.position.setValues(5, 8, 5);
      threeJs.camera.lookAt(three.Vector3(0, 0, 0));

      // Lights
      _setupLights();

      // Generate hex terrain
      await _generateTerrain();

      // Auto-rotate animation
      if (widget.autoRotateSpeed > 0) {
        threeJs.addAnimationEvent((dt) {
          threeJs.scene.rotation.y += dt * widget.autoRotateSpeed;
        });
      }
    } catch (e) {
      debugPrint('HexTerrain setup error: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _setupLights() {
    // Ambient light
    final ambient = three.AmbientLight(0x404040, 0.5);
    threeJs.scene.add(ambient);

    // Main directional light (sun-like)
    final directional = three.DirectionalLight(0xffffff, 1.0);
    directional.position.setValues(5, 10, 5);
    directional.castShadow = true;
    directional.shadow?.mapSize.width = 1024;
    directional.shadow?.mapSize.height = 1024;
    directional.shadow?.camera?.near = 0.5;
    directional.shadow?.camera?.far = 50;
    threeJs.scene.add(directional);

    // Fill light from below
    final fillLight = three.DirectionalLight(0x4080ff, 0.3);
    fillLight.position.setValues(-3, -5, -3);
    threeJs.scene.add(fillLight);

    // Hemisphere light for sky/ground gradient
    final hemi = three.HemisphereLight(0x87ceeb, 0x3a5a2a, 0.4);
    threeJs.scene.add(hemi);
  }

  Future<void> _generateTerrain() async {
    // Generate hex positions using scatter pattern (like useHexagonScatter)
    final hexPositions = _generateHexScatter(_terrainRadius);
    final random = math.Random(42);

    // Create a group to hold all hexes
    final terrainGroup = three.Group();

    // Pre-compute heights for all positions
    final heights = <double>[];
    for (final pos in hexPositions) {
      heights.add(_fbmNoise(pos.x * 0.12, pos.y * 0.12, random));
    }

    // Create individual meshes for each hex (since we need different heights)
    for (int i = 0; i < hexPositions.length; i++) {
      final pos = hexPositions[i];
      final height = heights[i];

      // Calculate actual height - water stays at water level
      final actualHeight = height <= _waterLevel ? _waterLevel : height;
      final hexHeight = actualHeight * _heightScale + 0.1;

      // Create hex geometry with proper height
      final hexGeometry = three.CylinderGeometry(
        _hexSize, // radiusTop
        _hexSize, // radiusBottom
        hexHeight, // height - THIS is the key difference
        6, // radialSegments (hexagon)
      );

      // Get color based on height
      final color = _getTerrainColor(height);

      final material = three.MeshPhongMaterial.fromMap({
        'color': color.getHex(),
        'flatShading': true,
      });

      final mesh = three.Mesh(hexGeometry, material);
      mesh.castShadow = true;
      mesh.receiveShadow = true;

      // Position: x, y (height/2 so bottom is at 0), z
      mesh.position.setValues(pos.x, hexHeight / 2, pos.y);

      terrainGroup.add(mesh);
    }

    // Rotate the whole terrain to lay flat (hexes point up)
    terrainGroup.rotation.x = -math.pi / 2;

    threeJs.scene.add(terrainGroup);
  }

  List<three.Vector2> _generateHexScatter(int radius) {
    final points = <three.Vector2>[];

    // Center hex
    points.add(three.Vector2(0, 0));

    const gap = 1.0;
    final unit = gap * 0.176 * 6; // Hex spacing unit
    const angle = math.pi / 3; // 60 degrees

    // Generate rings from center outward (like HexTerrain's useHexagonScatter)
    for (int ring = 1; ring <= radius; ring++) {
      for (int segment = 0; segment < 6; segment++) {
        for (int side = 0; side < ring; side++) {
          // Axis vector pointing outward
          final axisX = math.sin(segment * angle) * ring * unit;
          final axisY = -math.cos(segment * angle) * ring * unit;

          // Side vector for this segment
          final sideAngle = segment * angle + math.pi / 3;
          final sideX = math.sin(sideAngle) * side * unit;
          final sideY = -math.cos(sideAngle) * side * unit;

          points.add(three.Vector2(axisX + sideX, axisY + sideY));
        }
      }
    }

    return points;
  }

  double _fbmNoise(double x, double y, math.Random random) {
    // Multi-octave noise approximation using sin waves
    var value = 0.0;
    var amplitude = 1.0;
    var frequency = 1.0;

    for (int i = 0; i < 4; i++) {
      value +=
          amplitude *
          (math.sin(x * frequency * 3.7 + y * frequency * 2.3) * 0.5 +
              math.cos(y * frequency * 4.1 - x * frequency * 1.9) * 0.5);
      amplitude *= 0.5;
      frequency *= 2.0;
    }

    // Normalize and apply power curve
    return math.pow((value + 1) / 2, 2).clamp(0.0, 1.0).toDouble();
  }

  three.Color _getTerrainColor(double height) {
    // Biome thresholds matching HexTerrain
    const shoreLevel = 0.18;
    const beachLevel = 0.25;
    const grassLevel = 0.40;
    const shrubLevel = 0.55;
    const forestLevel = 0.70;
    const stoneLevel = 0.85;

    int colorHex;

    if (height <= _waterLevel) {
      // Water - cyan blue, darker at deeper levels
      final depth = height / _waterLevel;
      colorHex = _lerpColor(0xFF2080B0, _waterColor, depth);
    } else if (height <= shoreLevel) {
      // Shore - lighter blue
      colorHex = _shoreColor;
    } else if (height <= beachLevel) {
      // Beach/sand - warm beige
      colorHex = _beachColor;
    } else if (height <= grassLevel) {
      // Light grass - yellow-green (most prominent in HexTerrain)
      colorHex = _lerpColor(
        _shrubColor,
        0xFFA8B83A,
        (height - beachLevel) / (grassLevel - beachLevel),
      );
    } else if (height <= shrubLevel) {
      // Shrub - transitioning to darker green
      colorHex = _lerpColor(
        0xFF88A830,
        _forestColor,
        (height - grassLevel) / (shrubLevel - grassLevel),
      );
    } else if (height <= forestLevel) {
      // Forest - dark green
      colorHex = _lerpColor(
        _forestColor,
        _darkForestColor,
        (height - shrubLevel) / (forestLevel - shrubLevel),
      );
    } else if (height <= stoneLevel) {
      // Stone - gray
      colorHex = _lerpColor(
        _stoneColor,
        0xFF9A9A8A,
        (height - forestLevel) / (stoneLevel - forestLevel),
      );
    } else {
      // Snow - white
      colorHex = _lerpColor(
        0xFFCCCCCC,
        _snowColor,
        (height - stoneLevel) / (1.0 - stoneLevel),
      );
    }

    return three.Color.fromHex32(colorHex);
  }

  int _lerpColor(int color1, int color2, double t) {
    final r1 = (color1 >> 16) & 0xFF;
    final g1 = (color1 >> 8) & 0xFF;
    final b1 = color1 & 0xFF;

    final r2 = (color2 >> 16) & 0xFF;
    final g2 = (color2 >> 8) & 0xFF;
    final b2 = color2 & 0xFF;

    final r = (r1 + (r2 - r1) * t).round();
    final g = (g1 + (g2 - g1) * t).round();
    final b = (b1 + (b2 - b1) * t).round();

    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(color: AppTheme.darkBackground);
    }

    if (_hasError) {
      // Fallback to simple gradient if three_js fails
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              AppTheme.darkBackground,
              AppTheme.darkBackground.withValues(alpha: 0.8),
              const Color(0xFF1a3050),
            ],
          ),
        ),
      );
    }

    return Container(color: AppTheme.darkBackground, child: threeJs.build());
  }
}
