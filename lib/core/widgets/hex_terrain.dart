import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import '../theme.dart';
import '../logging.dart';

/// 3D Hexagonal terrain widget - Full port of HexTerrain
/// Uses three_js for WebGL rendering with support for trees, grass, clouds
class HexTerrain extends StatefulWidget {
  /// Auto-rotate speed (0 to disable)
  final double autoRotateSpeed;

  /// Whether to show the terrain
  final bool enabled;

  /// Whether to show trees
  final bool showTrees;

  /// Whether to show grass
  final bool showGrass;

  /// Whether to show clouds
  final bool showClouds;

  /// Random seed for terrain generation (null = random each time)
  final int? seed;

  const HexTerrain({
    super.key,
    this.autoRotateSpeed = 0.3,
    this.enabled = true,
    this.showTrees = false,
    this.showGrass = false,
    this.showClouds = false,
    this.seed,
  });

  @override
  State<HexTerrain> createState() => _HexTerrainState();
}

class _HexTerrainState extends State<HexTerrain> {
  late three.ThreeJS threeJs;
  bool _isInitialized = false;
  bool _hasError = false;

  // Generation settings (from appState.js)
  late final int _seed;
  static const double _height = 1.0;
  static const double _scale = 0.2;
  static const double _detail = 0.5;
  static const double _fuzzyness = 0.25;

  // Terrain parameters
  static const int _terrainRadius = 20;
  static const double _hexSize = 1.0;
  static const double _hexGap = 2.0;

  // Biome color thresholds (from appState.js)
  static const double _waterValue = 0.21;
  static const double _shoreValue = 0.01;
  static const double _beachValue = 0.04;
  static const double _shrubValue = 0.10;
  static const double _forestValue = 0.29;
  static const double _stoneValue = 0.36;

  // Biome colors (from appState.js)
  static const int _waterColor = 0x00a9ff;
  static const int _shoreColor = 0xffd68f;
  static const int _beachColor = 0xefb28f;
  static const int _shrubColor = 0x9ea667;
  static const int _forestColor = 0x586647;
  static const int _stoneColor = 0x656565;
  static const int _snowColor = 0x9aa7ad;

  // Store hex data for trees/grass placement
  final List<_HexData> _hexDataList = [];

  // Cloud animation data
  final List<_CloudPoint> _cloudPoints = [];
  three.Group? _cloudGroup;

  @override
  void initState() {
    super.initState();
    _seed = widget.seed ?? DateTime.now().millisecondsSinceEpoch;
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
        clearColor: context.background.toARGB32(),
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
        context.background.toARGB32(),
      );

      // Camera - looking down at terrain from above at an angle
      threeJs.camera = three.PerspectiveCamera(
        45,
        threeJs.width / threeJs.height,
        0.1,
        500,
      );
      // Position camera above and to the side, looking at center
      threeJs.camera.position.setValues(0, 10, 8);
      threeJs.camera.lookAt(three.Vector3(0, 0, 0));

      // Lights (matching Lights.jsx)
      _setupLights();

      // Generate hex terrain
      await _generateTerrain();

      // Add trees if enabled
      if (widget.showTrees) {
        await _addTrees();
      }

      // Add grass if enabled
      if (widget.showGrass) {
        await _addGrass();
      }

      // Add clouds if enabled
      if (widget.showClouds) {
        _addClouds();
      }

      // Auto-rotate animation
      if (widget.autoRotateSpeed > 0) {
        threeJs.addAnimationEvent((dt) {
          // Rotate around Y axis (vertical) for flat terrain rotation
          threeJs.scene.rotation.y += dt * widget.autoRotateSpeed;

          // Animate clouds
          if (widget.showClouds && _cloudGroup != null) {
            _animateClouds(dt);
          }
        });
      }
    } catch (e) {
      AppLogging.app('HexTerrain setup error: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _setupLights() {
    // Ambient light
    final ambient = three.AmbientLight(0xffffff, 0.4);
    threeJs.scene.add(ambient);

    // Main directional light (sun-like, from Lights.jsx)
    final directional = three.DirectionalLight(0xffffff, 1.5);
    directional.position.setValues(100, 200, 100);
    directional.castShadow = true;
    directional.shadow?.mapSize.width = 2048;
    directional.shadow?.mapSize.height = 2048;
    directional.shadow?.camera?.near = 0.5;
    directional.shadow?.camera?.far = 500;

    // Configure shadow camera bounds
    final shadowCam = directional.shadow?.camera;
    if (shadowCam is three.OrthographicCamera) {
      shadowCam.left = -200;
      shadowCam.right = 200;
      shadowCam.top = 200;
      shadowCam.bottom = -200;
    }

    threeJs.scene.add(directional);

    // Hemisphere light for sky/ground coloring
    final hemi = three.HemisphereLight(0x87ceeb, 0x3a5a2a, 0.3);
    threeJs.scene.add(hemi);
  }

  Future<void> _generateTerrain() async {
    final random = math.Random(_seed);

    // Generate hex positions using scatter pattern (useHexagonScatter.js)
    final hexPositions = _generateHexScatter(_terrainRadius, _hexGap);

    // Create terrain group
    final terrainGroup = three.Group();

    // Generate each hex with its own height and color
    for (final pos in hexPositions) {
      // Get height using FBM noise (useFBM.js)
      final scaledPos = three.Vector2(pos.x * _scale, pos.y * _scale);
      var height = _fbmNoise(scaledPos.x, scaledPos.y, random) * _height;

      // Get biome color based on height (useColor.js)
      final color = _getBiomeColor(height);

      // Water stays at water level
      if (height <= _waterValue) {
        height = _waterValue;
      }

      // Scale Z based on height (like ScatterHexagonMesh.jsx)
      final hexHeight = (height * 2.0).clamp(0.05, 2.0);

      // Create hexagonal prism using CylinderGeometry with 6 segments
      final geometry = three.CylinderGeometry(
        _hexSize * 0.08, // radiusTop
        _hexSize * 0.08, // radiusBottom
        hexHeight, // height
        6, // radialSegments (hexagon)
        1, // heightSegments
      );

      // Create material with this color
      final material = three.MeshPhongMaterial.fromMap({
        'color': color.getHex(),
        'flatShading': true,
        'side': three.FrontSide,
      });

      // Create mesh
      final mesh = three.Mesh(geometry, material);
      mesh.castShadow = true;
      mesh.receiveShadow = true;

      // Position hex on X-Z plane with Y as height
      // Cylinder is already vertical by default (Y-up)
      mesh.position.setValues(pos.x, hexHeight / 2, pos.y);

      terrainGroup.add(mesh);

      // Store hex data for trees/grass
      _hexDataList.add(
        _HexData(
          position: three.Vector3(pos.x, hexHeight, pos.y),
          height: height,
          biome: _getBiome(height),
        ),
      );
    }

    threeJs.scene.add(terrainGroup);
  }

  List<three.Vector2> _generateHexScatter(int radius, double gap) {
    final points = <three.Vector2>[];

    // Center hex
    points.add(three.Vector2(0, 0));

    // Hex spacing - gap is the distance between hex centers
    final unit = gap * 0.15; // Adjusted for proper hex tiling
    const angle = math.pi / 3;

    final axis = three.Vector3(0, 0, 1);
    final axisVector = three.Vector3(0, -unit, 0);
    final sideVector = three.Vector3(0, unit, 0);
    _rotateAroundAxis(sideVector, axis, -angle);

    final tempV3 = three.Vector3();

    for (int seg = 0; seg < 6; seg++) {
      for (int ax = 1; ax <= radius; ax++) {
        for (int sd = 0; sd < ax; sd++) {
          tempV3.setFrom(axisVector);
          tempV3.scale(ax.toDouble());

          final sideScaled = sideVector.clone();
          sideScaled.scale(sd.toDouble());
          tempV3.add(sideScaled);

          _rotateAroundAxis(tempV3, axis, angle * seg);

          points.add(three.Vector2(tempV3.x, tempV3.y));
        }
      }
    }

    return points;
  }

  void _rotateAroundAxis(three.Vector3 v, three.Vector3 axis, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    final t = 1 - c;

    final x = v.x;
    final y = v.y;
    final z = v.z;

    v.x =
        (t * axis.x * axis.x + c) * x +
        (t * axis.x * axis.y - s * axis.z) * y +
        (t * axis.x * axis.z + s * axis.y) * z;
    v.y =
        (t * axis.x * axis.y + s * axis.z) * x +
        (t * axis.y * axis.y + c) * y +
        (t * axis.y * axis.z - s * axis.x) * z;
    v.z =
        (t * axis.x * axis.z - s * axis.y) * x +
        (t * axis.y * axis.z + s * axis.x) * y +
        (t * axis.z * axis.z + c) * z;
  }

  double _fbmNoise(double x, double y, math.Random random) {
    // FBM (Fractal Brownian Motion) noise implementation (useFBM.js)
    // Using sin/cos combination to approximate Perlin noise
    final lacunarity = _detail * 4;
    final persistence = _fuzzyness * 2;

    var value = 0.0;
    var amplitude = 1.0;
    var frequency = 1.0;
    var maxValue = 0.0;

    // Use seed-based offset
    final seedOffset = _seed * 0.001;

    for (int i = 0; i < 4; i++) {
      // Simplex-like noise approximation
      final nx = (x + seedOffset) * frequency;
      final ny = (y + seedOffset) * frequency;

      final n =
          math.sin(nx * 1.27 + ny * 0.89) * math.cos(ny * 1.13 - nx * 0.97) +
          math.sin(nx * 2.31 - ny * 1.71) * 0.5;

      value += n * amplitude;
      maxValue += amplitude;

      amplitude *= persistence;
      frequency *= lacunarity;
    }

    // Normalize to 0-1 and apply power curve
    final normalized = (value / maxValue + 1) / 2;
    return math.pow(normalized.clamp(0.0, 1.0), 2).toDouble();
  }

  String _getBiome(double height) {
    if (height <= _waterValue) return 'water';
    if (height <= _waterValue + _shoreValue) return 'shore';
    if (height <= _waterValue + _beachValue) return 'beach';
    if (height <= _waterValue + _shrubValue) return 'shrub';
    if (height <= _waterValue + _forestValue) return 'forest';
    if (height <= _waterValue + _stoneValue) return 'stone';
    return 'snow';
  }

  three.Color _getBiomeColor(double height) {
    int colorHex;

    if (height <= _waterValue) {
      colorHex = _waterColor;
    } else if (height <= _waterValue + _shoreValue) {
      colorHex = _shoreColor;
    } else if (height <= _waterValue + _beachValue) {
      colorHex = _beachColor;
    } else if (height <= _waterValue + _shrubValue) {
      colorHex = _shrubColor;
    } else if (height <= _waterValue + _forestValue) {
      colorHex = _forestColor;
    } else if (height <= _waterValue + _stoneValue) {
      colorHex = _stoneColor;
    } else {
      colorHex = _snowColor;
    }

    final color = three.Color.fromHex32(0xFF000000 | colorHex);

    // Adjust water depth coloring (from useColor.js)
    if (height <= _waterValue) {
      final depthFactor = math.pow(1 - (_waterValue - height) * 1.3, 6);
      final mappedL = depthFactor.clamp(0.0, 1.0) * 1.4;
      // Darken water based on depth
      color.red = (color.red * mappedL).clamp(0.0, 1.0);
      color.green = (color.green * mappedL).clamp(0.0, 1.0);
      color.blue = (color.blue * mappedL).clamp(0.0, 1.0);
    }

    return color;
  }

  Future<void> _addTrees() async {
    final random = math.Random(_seed + 1);
    final treeGroup = three.Group();

    // Filter hexes that are in forest or stone biomes (from Trees.jsx)
    final treeHexes = _hexDataList
        .where((hex) => hex.biome == 'forest' || hex.biome == 'stone')
        .toList();

    // Create simple tree geometry (cone + cylinder)
    for (final hex in treeHexes) {
      // Random chance to place tree
      if (random.nextDouble() > 0.3) continue;

      // Create tree
      final tree = _createSimpleTree(random);

      // Position tree on hex (Y is height)
      tree.position.setValues(
        hex.position.x + (random.nextDouble() - 0.5) * 0.05,
        hex.position.y, // Y is the height
        hex.position.z + (random.nextDouble() - 0.5) * 0.05,
      );

      // Random rotation around Y axis
      tree.rotation.y = random.nextDouble() * math.pi * 2;

      // Random scale
      final scale = 0.02 + random.nextDouble() * 0.02;
      tree.scale.setValues(scale, scale, scale);

      treeGroup.add(tree);
    }

    threeJs.scene.add(treeGroup);
  }

  three.Group _createSimpleTree(math.Random random) {
    final tree = three.Group();

    // Trunk (brown cylinder) - already Y-up by default
    final trunkGeometry = three.CylinderGeometry(0.3, 0.4, 2.0, 8);
    final trunkMaterial = three.MeshPhongMaterial.fromMap({
      'color': 0x4a3728,
      'flatShading': true,
    });
    final trunk = three.Mesh(trunkGeometry, trunkMaterial);
    trunk.position.y = 1.0;
    trunk.castShadow = true;
    tree.add(trunk);

    // Foliage (green cone) - already Y-up by default
    final foliageGeometry = three.ConeGeometry(1.2, 3.0, 8);
    final foliageColor = random.nextBool() ? 0x2d5a27 : 0x3d6a37;
    final foliageMaterial = three.MeshPhongMaterial.fromMap({
      'color': foliageColor,
      'flatShading': true,
    });
    final foliage = three.Mesh(foliageGeometry, foliageMaterial);
    foliage.position.y = 3.5;
    foliage.castShadow = true;
    tree.add(foliage);

    return tree;
  }

  Future<void> _addGrass() async {
    final random = math.Random(_seed + 2);
    final grassGroup = three.Group();

    // Filter hexes that are in beach to forest biomes (from Grass.jsx)
    final grassHexes = _hexDataList
        .where(
          (hex) =>
              hex.biome == 'beach' ||
              hex.biome == 'shrub' ||
              hex.biome == 'forest',
        )
        .toList();

    // Create grass patches
    for (final hex in grassHexes) {
      // Multiple grass blades per hex
      final bladeCount = 2 + random.nextInt(4);
      for (int i = 0; i < bladeCount; i++) {
        if (random.nextDouble() > 0.5) continue;

        final grass = _createGrassBlade(random);

        grass.position.setValues(
          hex.position.x + (random.nextDouble() - 0.5) * 0.08,
          hex.position.y, // Y is height
          hex.position.z + (random.nextDouble() - 0.5) * 0.08,
        );

        grass.rotation.y = random.nextDouble() * math.pi * 2;

        final scale = 0.01 + random.nextDouble() * 0.015;
        grass.scale.setValues(scale, scale, scale);

        grassGroup.add(grass);
      }
    }

    threeJs.scene.add(grassGroup);
  }

  three.Mesh _createGrassBlade(math.Random random) {
    // Simple grass blade as a thin box (Y-up)
    final geometry = three.BoxGeometry(0.1, 1.5, 0.1);
    final grassColor = random.nextBool() ? 0x7a9a57 : 0x8aaa67;
    final material = three.MeshPhongMaterial.fromMap({
      'color': grassColor,
      'flatShading': true,
    });
    final blade = three.Mesh(geometry, material);
    blade.position.y = 0.75; // Half height up
    return blade;
  }

  void _addClouds() {
    final random = math.Random(_seed + 3);
    _cloudGroup = three.Group();
    _cloudGroup!.position.y = 8; // Cloud height (Y-up)

    // Generate cloud points
    for (int i = 0; i < 30; i++) {
      _cloudPoints.add(
        _CloudPoint(
          position: three.Vector3(
            (random.nextDouble() * 16 - 8) * 5,
            0, // Y offset within cloud layer
            (random.nextDouble() * 16 - 8) * 5,
          ),
          scale: 0.1 + random.nextDouble() * 0.1,
          rate: 5 + random.nextDouble() * 5,
        ),
      );
    }

    // Create cloud meshes
    for (final point in _cloudPoints) {
      final cloud = _createCloud(random);
      cloud.position.setFrom(point.position);
      cloud.scale.setScalar(point.scale);
      _cloudGroup!.add(cloud);
    }

    threeJs.scene.add(_cloudGroup!);
  }

  three.Mesh _createCloud(math.Random random) {
    // Simple cloud as a flattened sphere
    final geometry = three.SphereGeometry(2, 8, 6);
    final material = three.MeshPhongMaterial.fromMap({
      'color': 0xffffff,
      'opacity': 0.9,
      'transparent': true,
    });
    final cloud = three.Mesh(geometry, material);
    cloud.castShadow = true;

    // Flatten cloud (squash Y)
    cloud.scale.y = 0.3;

    return cloud;
  }

  void _animateClouds(double dt) {
    if (_cloudGroup == null) return;

    for (
      int i = 0;
      i < _cloudPoints.length && i < _cloudGroup!.children.length;
      i++
    ) {
      final point = _cloudPoints[i];
      final cloud = _cloudGroup!.children[i];

      // Move cloud along X
      point.position.x += dt * point.rate;

      // Wrap around
      if (point.position.x > 40) {
        point.position.x = -40;
        point.position.z = (math.Random().nextDouble() * 80) - 40;
      }

      // Update position
      cloud.position.setFrom(point.position);

      // Fade at edges
      final fadeScale = math.pow(1 - (point.position.x.abs() / 40), 0.5);
      cloud.scale.setScalar(point.scale * fadeScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Container(color: context.background);
    }

    if (_hasError) {
      // Fallback to simple gradient if three_js fails
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              context.background,
              context.background.withValues(alpha: 0.8),
              const Color(0xFF1a3050),
            ],
          ),
        ),
      );
    }

    return Container(color: context.background, child: threeJs.build());
  }
}

/// Stores data for each hex in the terrain
class _HexData {
  final three.Vector3 position;
  final double height;
  final String biome;

  _HexData({required this.position, required this.height, required this.biome});
}

/// Stores data for cloud animation
class _CloudPoint {
  three.Vector3 position;
  final double scale;
  final double rate;

  _CloudPoint({
    required this.position,
    required this.scale,
    required this.rate,
  });
}
