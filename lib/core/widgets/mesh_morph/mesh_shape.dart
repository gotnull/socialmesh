// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Dart port of the rsvpnano ShapeRegistry (src/screensaver/ShapeRegistry.cpp).
// Each generator fills a fixed-length list of Point3D positions; the calling
// painter does rotation + perspective + projection in the same pass as the
// existing AnimatedMeshNode.
//
// Why a port: rsvpnano's screensaver morphs through 15 hand-built shape
// templates (cube, sphere, torus, helix, …, icosahedron) with continuous
// linear interpolation. This file recreates that catalog in Dart so the
// SocialMesh app can drive its own morphing animations with the same set
// of "natural vectorball density" shapes that the firmware uses.
//
// Density philosophy: each generator picks its own grid / stride so the
// classic Equinox-vectorball density shines through for that topology.
// Sphere stays at full N (Fibonacci uniform), trefoil/möbius stack onto
// fewer distinct positions, edge wireframes (octahedron / pyramid /
// icosahedron) place samples along edges. See the per-shape comments.

import 'dart:math' as math;

/// One ball in 3D model space. Coordinates are roughly bounded by ±1.0
/// so the painter can choose any panel size at projection time.
class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);

  /// Linear interpolation between this point and [other] by [t] in [0..1].
  Point3D lerp(Point3D other, double t) => Point3D(
    x + (other.x - x) * t,
    y + (other.y - y) * t,
    z + (other.z - z) * t,
  );
}

/// Edge (a, b) between two indices into a shape's points list. Used by the
/// wireframe shapes (octahedron, pyramid, icosahedron) and by any morph
/// keyframe that wants to draw connecting lines. Surface / volume shapes
/// return null from `edges` because their "natural" rendering is just dots.
typedef ShapeEdge = (int, int);

/// Canonical shape ids matching the rsvpnano firmware ordering. Kept stable
/// so a morph sequence by id round-trips between Dart and C++ tooling if we
/// ever want to share preset definitions between the two.
enum MeshShapeId {
  cube,
  sphere,
  torus,
  helix,
  doubleHelix,
  randomCloud,
  wavePlane,
  lissajous,
  octahedron,
  trefoil,
  mobius,
  hyperboloid,
  saddle,
  pyramid,
  icosahedron,
}

/// A shape generator produces `pointCount` Point3D positions deterministically.
/// Implementations are pure functions of (pointCount, seed) — same inputs →
/// identical output across rebuilds, identical morph targets across re-entries.
abstract class MeshShape {
  MeshShapeId get id;
  String get displayName;

  /// Fill the shape's positions into `out`. The list is pre-sized to
  /// [pointCount] entries by the caller; the generator writes in place so
  /// the painter can re-use the buffer across frames.
  void fill(List<Point3D> out, {int seed = 0});

  /// Optional edges between point indices. Only set for wireframe shapes;
  /// surface / cloud shapes return null and the painter just draws dots.
  List<ShapeEdge>? get edges => null;
}

// ---------------------------------------------------------------------------
// Math helpers
// ---------------------------------------------------------------------------

double _cos(double a) => math.cos(a);
double _sin(double a) => math.sin(a);
double _sqrt(double a) => math.sqrt(a);

/// Tiny deterministic LCG matching the rsvpnano firmware's ShapeRng so cloud
/// shapes reproduce identically across rebuilds.
class _LcgRng {
  int _state;
  _LcgRng(int seed) : _state = seed == 0 ? 0xC0DECAFE : seed;
  double next() {
    // Same LCG params as rsvpnano ShapeRng::frand.
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return ((_state >> 8) & 0xFFFFFF) / 16777216.0;
  }
}

const double _modelScale = 1.0;
const double _sphereRadius = 1.0;

// ---------------------------------------------------------------------------
// Shape 0 — Cube grid. 6³ filled cube. Always uses 216 distinct points; if
// pointCount < 216 the cube downsamples to fit a smaller cubic grid; if it
// exceeds 216 the grid is upsampled in the same dimensions.
// ---------------------------------------------------------------------------

class CubeShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.cube;
  @override
  String get displayName => 'Cube';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final perAxis = math.max(2, math.pow(n, 1 / 3).round());
    final step = 2.0 / (perAxis - 1);
    int idx = 0;
    for (int i = 0; i < perAxis && idx < n; i++) {
      for (int j = 0; j < perAxis && idx < n; j++) {
        for (int k = 0; k < perAxis && idx < n; k++) {
          out[idx] = Point3D(
            (-1.0 + i * step) * _modelScale,
            (-1.0 + j * step) * _modelScale,
            (-1.0 + k * step) * _modelScale,
          );
          idx++;
        }
      }
    }
    // Pad any leftover slots with the centre — these stack with no visual
    // penalty (renderer paints them on top of an existing dot at origin).
    while (idx < n) {
      out[idx++] = const Point3D(0, 0, 0);
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 1 — Sphere (Fibonacci-spiral distribution). Uniform within ~1
// nearest-neighbour distance, no clumps, no holes. Direct port of
// rsvpnano's genSphere.
// ---------------------------------------------------------------------------

class SphereShape extends MeshShape {
  static const double _goldenAngle = 2.39996323; // π·(3 − √5)

  @override
  MeshShapeId get id => MeshShapeId.sphere;
  @override
  String get displayName => 'Sphere';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    for (int i = 0; i < n; i++) {
      final y = 1.0 - (i + 0.5) * (2.0 / n);
      final r = _sqrt(1 - y * y);
      final theta = _goldenAngle * i;
      out[i] = Point3D(
        _sphereRadius * _cos(theta) * r,
        _sphereRadius * y,
        _sphereRadius * _sin(theta) * r,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 2 — Torus. Grid sized so adjacent neighbours stay readable both
// around the major loop and around the tube cross-section.
// ---------------------------------------------------------------------------

class TorusShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.torus;
  @override
  String get displayName => 'Torus';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    // Roughly 4:3 aspect (u:v) — picked empirically to read as a fat ring.
    final v = math.max(4, _sqrt(n / 1.33).round());
    final u = math.max(4, (n / v).floor());
    const majorR = 0.66;
    const minorR = 0.33;
    for (int i = 0; i < n; i++) {
      final iu = i % u;
      final iv = (i ~/ u) % v;
      final ua = (iu / u) * 2 * math.pi;
      final va = (iv / v) * 2 * math.pi;
      out[i] = Point3D(
        (majorR + minorR * _cos(va)) * _cos(ua),
        minorR * _sin(va),
        (majorR + minorR * _cos(va)) * _sin(ua),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 3 — Single-helix tube. Thin tube wrapped around a helical core; the
// 2D u/v parametrisation keeps adjacent samples well-spaced both along the
// curve and around the cross-section.
// ---------------------------------------------------------------------------

class HelixShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.helix;
  @override
  String get displayName => 'Helix';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final v = math.max(4, _sqrt(n / 2.7).round()); // around-tube
    final u = math.max(4, (n / v).floor()); // along-curve
    const r = 0.66;
    const tubeR = 0.30;
    for (int i = 0; i < n; i++) {
      final iu = i % u;
      final iv = (i ~/ u) % v;
      final t = u <= 1 ? 0.0 : iu / (u - 1);
      final theta = t * 2 * math.pi;
      final phi = (iv / v) * 2 * math.pi;
      final radial = r + tubeR * _cos(phi);
      out[i] = Point3D(
        radial * _cos(theta),
        (t * 2 - 1) * _modelScale + tubeR * _sin(phi),
        radial * _sin(theta),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 4 — Double helix. Two tube strands 180° apart; per-strand grid is
// half the total point count.
// ---------------------------------------------------------------------------

class DoubleHelixShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.doubleHelix;
  @override
  String get displayName => 'Double Helix';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final perStrand = n ~/ 2;
    final v = math.max(3, _sqrt(perStrand / 3.0).round());
    final u = math.max(3, (perStrand / v).floor());
    const r = 0.66;
    const tubeR = 0.20;
    for (int i = 0; i < n; i++) {
      final strand = i ~/ (u * v);
      final local = i % (u * v);
      final iu = local % u;
      final iv = local ~/ u;
      final t = u <= 1 ? 0.0 : iu / (u - 1);
      final theta = t * 2 * math.pi + (strand == 1 ? math.pi : 0.0);
      final phi = (iv / v) * 2 * math.pi;
      final radial = r + tubeR * _cos(phi);
      out[i] = Point3D(
        radial * _cos(theta),
        (t * 2 - 1) * _modelScale + tubeR * _sin(phi),
        radial * _sin(theta),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 5 — Random cloud. Deterministic LCG seed so the cloud is identical
// across rebuilds.
// ---------------------------------------------------------------------------

class RandomCloudShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.randomCloud;
  @override
  String get displayName => 'Cloud';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final rng = _LcgRng(seed);
    for (int i = 0; i < out.length; i++) {
      out[i] = Point3D(
        (rng.next() * 2 - 1) * _modelScale,
        (rng.next() * 2 - 1) * _modelScale,
        (rng.next() * 2 - 1) * _modelScale,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 6 — Wave-plane ripple. cos(r) × falloff so it reads as a pond
// ripple rather than a stripey saddle.
// ---------------------------------------------------------------------------

class WavePlaneShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.wavePlane;
  @override
  String get displayName => 'Wave Plane';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final v = math.max(2, _sqrt(n / 1.5).round());
    final u = math.max(2, (n / v).floor());
    for (int i = 0; i < n; i++) {
      final iu = i % u;
      final iv = (i ~/ u) % v;
      final ua = u <= 1 ? 0.0 : (iu / (u - 1)) * 2 - 1;
      final va = v <= 1 ? 0.0 : (iv / (v - 1)) * 2 - 1;
      final r = _sqrt(ua * ua + va * va);
      final falloff = r > 1.4 ? 0.0 : (1 - r / 1.4);
      out[i] = Point3D(
        ua * _modelScale,
        _cos(r * 6) * 0.4 * falloff,
        va * _modelScale,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 7 — Lissajous blob. Three irrational frequency ratios produce a
// non-repeating 3D figure-8 cluster.
// ---------------------------------------------------------------------------

class LissajousShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.lissajous;
  @override
  String get displayName => 'Lissajous';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    for (int i = 0; i < out.length; i++) {
      final m = i.toDouble();
      out[i] = Point3D(
        _cos(0.2094 * m) * _sin(0.3141 * m) * 0.9 * _modelScale,
        _sin(0.2692 * m) * _sin(0.1884 * m) * 0.9 * _modelScale,
        _sin(0.3769 * m) * _modelScale,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Wireframe edge generator helper. Distributes [pointCount] indices across
// [edgeCount] edges. Returns (vertexA, vertexB) pairs for the rendered
// edges (a permutation of the edge list deduped on point indices).
// ---------------------------------------------------------------------------

void _fillEdgeWireframe({
  required List<Point3D> out,
  required List<Point3D> vertices,
  required List<List<int>> edges,
  required double scale,
}) {
  final n = out.length;
  final perEdge = math.max(2, n ~/ edges.length);
  int idx = 0;
  for (final e in edges) {
    if (idx >= n) break;
    final a = vertices[e[0]];
    final b = vertices[e[1]];
    for (int k = 0; k < perEdge && idx < n; k++) {
      final t = perEdge <= 1 ? 0.0 : k / (perEdge - 1);
      out[idx++] = Point3D(
        (a.x + (b.x - a.x) * t) * scale,
        (a.y + (b.y - a.y) * t) * scale,
        (a.z + (b.z - a.z) * t) * scale,
      );
    }
  }
  // Pad remainder with vertex caps so the morph buffer stays full.
  int c = 0;
  while (idx < n) {
    final v = vertices[c % vertices.length];
    out[idx++] = Point3D(v.x * scale, v.y * scale, v.z * scale);
    c++;
  }
}

// ---------------------------------------------------------------------------
// Shape 8 — Octahedron edges. 6 verts, 12 edges.
// ---------------------------------------------------------------------------

class OctahedronShape extends MeshShape {
  static const double _r = 0.85;
  static const List<Point3D> _verts = [
    Point3D(1, 0, 0),
    Point3D(-1, 0, 0),
    Point3D(0, 1, 0),
    Point3D(0, -1, 0),
    Point3D(0, 0, 1),
    Point3D(0, 0, -1),
  ];
  static const List<List<int>> _edgeList = [
    [0, 2],
    [0, 3],
    [0, 4],
    [0, 5],
    [1, 2],
    [1, 3],
    [1, 4],
    [1, 5],
    [2, 4],
    [2, 5],
    [3, 4],
    [3, 5],
  ];

  @override
  MeshShapeId get id => MeshShapeId.octahedron;
  @override
  String get displayName => 'Octahedron';

  @override
  void fill(List<Point3D> out, {int seed = 0}) => _fillEdgeWireframe(
    out: out,
    vertices: _verts,
    edges: _edgeList,
    scale: _r,
  );

  @override
  List<ShapeEdge>? get edges => [for (final e in _edgeList) (e[0], e[1])];
}

// ---------------------------------------------------------------------------
// Shape 9 — Trefoil knot. Curve length ≈ 11·scale; stack onto fewer
// distinct samples than pointCount so adjacent dots don't visibly overlap
// where the curve doubles back on itself.
// ---------------------------------------------------------------------------

class TrefoilShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.trefoil;
  @override
  String get displayName => 'Trefoil';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final distinct = math.max(12, n ~/ 3);
    const knotScale = 0.33;
    for (int i = 0; i < n; i++) {
      final vis = (i * distinct) ~/ n;
      final t = (vis / distinct) * 2 * math.pi;
      out[i] = Point3D(
        (_sin(t) + 2 * _sin(2 * t)) * knotScale,
        (_cos(t) - 2 * _cos(2 * t)) * knotScale,
        -_sin(3 * t) * knotScale * 1.5,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 10 — Möbius strip. Wide strip so the half-twist reads clearly when
// the band rotates through the camera.
// ---------------------------------------------------------------------------

class MobiusShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.mobius;
  @override
  String get displayName => 'Möbius';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final v = math.max(3, _sqrt(n / 2.0).round());
    final u = math.max(3, (n / v).floor());
    const bigR = 0.72;
    const halfWidth = 0.45;
    for (int i = 0; i < n; i++) {
      final iu = i % u;
      final iv = (i ~/ u) % v;
      final ua = (iu / u) * 2 * math.pi;
      final va = v <= 1 ? 0.0 : (iv / (v - 1)) * 2 - 1;
      final w = va * halfWidth;
      final c = _cos(ua * 0.5);
      final s = _sin(ua * 0.5);
      final radial = bigR + w * c;
      out[i] = Point3D(radial * _cos(ua), w * s, radial * _sin(ua));
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 11 — Hyperboloid of one sheet. Cooling-tower hourglass.
// ---------------------------------------------------------------------------

class HyperboloidShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.hyperboloid;
  @override
  String get displayName => 'Hyperboloid';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final v = math.max(3, _sqrt(n / 2.7).round());
    final u = math.max(4, (n / v).floor());
    const waistR = 0.40;
    const halfH = 0.85;
    for (int i = 0; i < n; i++) {
      final iu = i % u;
      final iv = (i ~/ u) % v;
      final t = v <= 1 ? 0.0 : (iv / (v - 1)) * 2 - 1;
      final z = t * halfH;
      final r = waistR * _sqrt(1 + t * t * 3);
      final ua = (iu / u) * 2 * math.pi;
      out[i] = Point3D(r * _cos(ua), z, r * _sin(ua));
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 12 — Hyperbolic-paraboloid saddle.
// ---------------------------------------------------------------------------

class SaddleShape extends MeshShape {
  @override
  MeshShapeId get id => MeshShapeId.saddle;
  @override
  String get displayName => 'Saddle';

  @override
  void fill(List<Point3D> out, {int seed = 0}) {
    final n = out.length;
    final v = math.max(2, _sqrt(n / 1.5).round());
    final u = math.max(2, (n / v).floor());
    for (int i = 0; i < n; i++) {
      final iu = i % u;
      final iv = (i ~/ u) % v;
      final ua = u <= 1 ? 0.0 : (iu / (u - 1)) * 2 - 1;
      final va = v <= 1 ? 0.0 : (iv / (v - 1)) * 2 - 1;
      out[i] = Point3D(
        ua * _modelScale,
        (ua * ua - va * va) * 0.6,
        va * _modelScale,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Shape 13 — Square pyramid edges. 4-vertex base + apex, 8 edges.
// ---------------------------------------------------------------------------

class PyramidShape extends MeshShape {
  static const double _r = 0.85;
  static const List<Point3D> _verts = [
    Point3D(-1, -1, -1), Point3D(1, -1, -1),
    Point3D(1, -1, 1), Point3D(-1, -1, 1),
    Point3D(0, 1, 0), // apex
  ];
  static const List<List<int>> _edgeList = [
    [0, 1], [1, 2], [2, 3], [3, 0], // base
    [0, 4], [1, 4], [2, 4], [3, 4], // slants
  ];

  @override
  MeshShapeId get id => MeshShapeId.pyramid;
  @override
  String get displayName => 'Pyramid';

  @override
  void fill(List<Point3D> out, {int seed = 0}) => _fillEdgeWireframe(
    out: out,
    vertices: _verts,
    edges: _edgeList,
    scale: _r,
  );

  @override
  List<ShapeEdge>? get edges => [for (final e in _edgeList) (e[0], e[1])];
}

// ---------------------------------------------------------------------------
// Shape 14 — Icosahedron edge wireframe. 12 vertices, 30 edges. The 12
// vertex caps are exposed via edges so the painter can render the same
// "glowing vertex balls + connecting lines" look as the SocialMesh logo.
// ---------------------------------------------------------------------------

class IcosahedronShape extends MeshShape {
  static const double _phi = 1.6180339887;
  static const double _scale = 0.85 / 1.902;
  // Edge list copied 1:1 from the existing _IcosahedronPainter in
  // animated_mesh_node.dart so the SocialMesh splash and morph stay in sync.
  static const List<List<int>> _edgeList = [
    [0, 1],
    [0, 5],
    [0, 7],
    [0, 10],
    [0, 11],
    [1, 5],
    [1, 7],
    [1, 8],
    [1, 9],
    [5, 9],
    [5, 4],
    [5, 11],
    [9, 4],
    [9, 3],
    [9, 8],
    [4, 3],
    [4, 2],
    [4, 11],
    [3, 2],
    [3, 6],
    [3, 8],
    [2, 6],
    [2, 10],
    [2, 11],
    [6, 7],
    [6, 8],
    [6, 10],
    [7, 8],
    [7, 10],
    [10, 11],
  ];
  static final List<Point3D> _verts = _buildVerts();

  static List<Point3D> _buildVerts() {
    final raw = [
      const Point3D(-1, _phi, 0),
      const Point3D(1, _phi, 0),
      const Point3D(-1, -_phi, 0),
      const Point3D(1, -_phi, 0),
      const Point3D(0, -1, _phi),
      const Point3D(0, 1, _phi),
      const Point3D(0, -1, -_phi),
      const Point3D(0, 1, -_phi),
      const Point3D(_phi, 0, -1),
      const Point3D(_phi, 0, 1),
      const Point3D(-_phi, 0, -1),
      const Point3D(-_phi, 0, 1),
    ];
    return raw
        .map((v) => Point3D(v.x * _scale, v.y * _scale, v.z * _scale))
        .toList(growable: false);
  }

  @override
  MeshShapeId get id => MeshShapeId.icosahedron;
  @override
  String get displayName => 'Icosahedron';

  @override
  void fill(List<Point3D> out, {int seed = 0}) => _fillEdgeWireframe(
    out: out,
    vertices: _verts,
    edges: _edgeList,
    scale: 1.0,
  );

  @override
  List<ShapeEdge>? get edges => [for (final e in _edgeList) (e[0], e[1])];
}

// ---------------------------------------------------------------------------
// Registry — order MUST match the MeshShapeId enum so byId lookups stay O(1).
// ---------------------------------------------------------------------------

final List<MeshShape> meshShapeRegistry = List<MeshShape>.unmodifiable([
  CubeShape(),
  SphereShape(),
  TorusShape(),
  HelixShape(),
  DoubleHelixShape(),
  RandomCloudShape(),
  WavePlaneShape(),
  LissajousShape(),
  OctahedronShape(),
  TrefoilShape(),
  MobiusShape(),
  HyperboloidShape(),
  SaddleShape(),
  PyramidShape(),
  IcosahedronShape(),
]);

MeshShape shapeById(MeshShapeId id) => meshShapeRegistry[id.index];
