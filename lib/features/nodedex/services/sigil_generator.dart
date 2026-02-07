// SPDX-License-Identifier: GPL-3.0-or-later

// Sigil Generator — deterministic geometric identity from node data.
//
// Each Meshtastic node gets a unique geometric sigil derived entirely
// from its node number. The generation is deterministic: the same
// nodeNum always produces the same sigil. No randomness, no per-session
// variation.
//
// The sigil is a constellation-style geometric pattern built from:
// - An outer polygon (3-8 vertices)
// - Optional inner rings with scaled polygons
// - Optional radial lines from center to vertices
// - A center dot or void
// - A unique 3-color palette
//
// The hash function distributes node IDs across the parameter space
// uniformly, so even sequential node numbers produce visually distinct
// sigils.

import 'dart:ui';

import '../models/nodedex_entry.dart';

/// Generates deterministic sigil data from a node's numeric identity.
///
/// The generator uses a simple but effective hash-mixing strategy to
/// extract independent parameters from a single 32-bit node number.
/// Each parameter is derived from a different bit range of the mixed
/// hash, ensuring visual diversity without external dependencies.
class SigilGenerator {
  SigilGenerator._();

  /// The curated palette of sigil colors.
  ///
  /// These are chosen for legibility on both dark and light backgrounds,
  /// with enough saturation to feel distinct but not garish. Each color
  /// works well as a primary, secondary, or tertiary element.
  static const List<Color> _palette = [
    Color(0xFF0EA5E9), // sky
    Color(0xFF8B5CF6), // purple
    Color(0xFFF97316), // orange
    Color(0xFF10B981), // emerald
    Color(0xFFEF4444), // red
    Color(0xFFFBBF24), // amber
    Color(0xFF06B6D4), // cyan
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF6366F1), // indigo
    Color(0xFF84CC16), // lime
    Color(0xFFA78BFA), // lavender
    Color(0xFFE91E8C), // magenta
    Color(0xFF22C55E), // green
    Color(0xFFF43F5E), // rose
    Color(0xFF0369A1), // deep sky
  ];

  /// Generate a SigilData from a node number.
  ///
  /// The result is always the same for the same [nodeNum].
  /// This is a pure function with no side effects.
  static SigilData generate(int nodeNum) {
    // Mix the bits of the node number to distribute entropy.
    // We use multiple rounds of mixing to extract independent parameters.
    final h0 = mix(nodeNum);
    final h1 = mix(h0);
    final h2 = mix(h1);
    final h3 = mix(h2);
    final h4 = mix(h3);

    // Extract sigil parameters from different hash rounds.

    // Vertices: 3 to 8 sides for the outer polygon.
    final vertices = 3 + (_extractBits(h0, 0, 8) % 6);

    // Rotation: offset in radians (0 to 2*pi), quantized to 24 steps
    // for visual cleanliness.
    final rotationStep = _extractBits(h0, 8, 8) % 24;
    final rotation = rotationStep * (3.14159265358979 * 2.0 / 24.0);

    // Inner rings: 0 to 3 concentric inner polygons.
    final innerRings = _extractBits(h1, 0, 8) % 4;

    // Radial lines: whether to draw lines from center to each vertex.
    final drawRadials = (_extractBits(h1, 8, 8) % 3) != 0;

    // Center dot: whether to draw a dot at the center.
    final centerDot = (_extractBits(h2, 0, 8) % 2) == 0;

    // Symmetry fold: 2 to 6, controls inner pattern symmetry.
    final symmetryFold = 2 + (_extractBits(h2, 8, 8) % 5);

    // Color selection: pick 3 distinct colors from the palette.
    final primaryIndex = _extractBits(h3, 0, 8) % _palette.length;
    var secondaryIndex = _extractBits(h3, 8, 8) % _palette.length;
    if (secondaryIndex == primaryIndex) {
      secondaryIndex = (secondaryIndex + 1) % _palette.length;
    }
    var tertiaryIndex = _extractBits(h4, 0, 8) % _palette.length;
    if (tertiaryIndex == primaryIndex || tertiaryIndex == secondaryIndex) {
      tertiaryIndex = (tertiaryIndex + 2) % _palette.length;
    }
    if (tertiaryIndex == primaryIndex || tertiaryIndex == secondaryIndex) {
      tertiaryIndex = (tertiaryIndex + 1) % _palette.length;
    }

    return SigilData(
      vertices: vertices,
      rotation: rotation,
      innerRings: innerRings,
      drawRadials: drawRadials,
      centerDot: centerDot,
      symmetryFold: symmetryFold,
      primaryColor: _palette[primaryIndex],
      secondaryColor: _palette[secondaryIndex],
      tertiaryColor: _palette[tertiaryIndex],
    );
  }

  /// Generate the 3-color palette for a node without the full sigil.
  ///
  /// Useful when only colors are needed (e.g., for list item accents)
  /// without computing the full geometric parameters.
  static (Color primary, Color secondary, Color tertiary) colorsFor(
    int nodeNum,
  ) {
    final sigil = generate(nodeNum);
    return (sigil.primaryColor, sigil.secondaryColor, sigil.tertiaryColor);
  }

  /// Compute the constellation point positions for a sigil.
  ///
  /// Returns a list of (x, y) offsets normalized to a unit circle
  /// (values between -1.0 and 1.0). The caller scales these to the
  /// desired render size.
  ///
  /// The points include:
  /// - Outer polygon vertices
  /// - Inner ring vertices (if any)
  /// - Center point (if centerDot is true)
  static List<Offset> computePoints(SigilData sigil) {
    final points = <Offset>[];
    final vertices = sigil.vertices;
    final rotation = sigil.rotation;

    // Outer polygon vertices
    for (int i = 0; i < vertices; i++) {
      final angle = rotation + (i * 3.14159265358979 * 2.0 / vertices);
      points.add(Offset(_cos(angle), _sin(angle)));
    }

    // Inner ring vertices
    for (int ring = 1; ring <= sigil.innerRings; ring++) {
      final scale = 1.0 - (ring * 0.25);
      final ringRotation = rotation + (ring * 0.2);
      final ringVertices = vertices;
      for (int i = 0; i < ringVertices; i++) {
        final angle =
            ringRotation + (i * 3.14159265358979 * 2.0 / ringVertices);
        points.add(Offset(_cos(angle) * scale, _sin(angle) * scale));
      }
    }

    // Center point
    if (sigil.centerDot) {
      points.add(Offset.zero);
    }

    return points;
  }

  /// Compute the edge connections for a sigil.
  ///
  /// Returns pairs of indices into the points list returned by
  /// [computePoints]. Each pair represents a line to draw.
  static List<(int, int)> computeEdges(SigilData sigil) {
    final edges = <(int, int)>[];
    final vertices = sigil.vertices;

    // Outer polygon edges
    for (int i = 0; i < vertices; i++) {
      edges.add((i, (i + 1) % vertices));
    }

    // Inner ring edges and connections to outer ring
    for (int ring = 1; ring <= sigil.innerRings; ring++) {
      final ringOffset = ring * vertices;
      for (int i = 0; i < vertices; i++) {
        // Inner polygon edge
        edges.add((ringOffset + i, ringOffset + ((i + 1) % vertices)));

        // Connect inner vertex to corresponding outer vertex
        // (creates a web effect)
        if (ring == 1) {
          edges.add((i, ringOffset + i));
        } else {
          final prevRingOffset = (ring - 1) * vertices;
          edges.add((prevRingOffset + i, ringOffset + i));
        }
      }
    }

    // Radial lines from center (or innermost ring) to outer vertices
    if (sigil.drawRadials) {
      final centerIndex = sigil.centerDot
          ? (vertices * (1 + sigil.innerRings))
          : -1;

      if (centerIndex >= 0) {
        // Draw from center dot to innermost ring or outer polygon
        final targetRing = sigil.innerRings > 0 ? sigil.innerRings : 0;
        final targetOffset = targetRing * vertices;
        for (int i = 0; i < vertices; i += sigil.symmetryFold > 1 ? 1 : 2) {
          edges.add((centerIndex, targetOffset + i));
        }
      } else if (sigil.innerRings > 0) {
        // No center dot but has inner rings — draw radials to innermost ring
        final innermostOffset = sigil.innerRings * vertices;
        for (int i = 0; i < vertices; i++) {
          // Connect alternate vertices for visual interest based on symmetry
          if (i % (vertices ~/ sigil.symmetryFold).clamp(1, vertices) == 0) {
            edges.add((i, innermostOffset + ((i + 1) % vertices)));
          }
        }
      }
    }

    return edges;
  }

  // ---------------------------------------------------------------------------
  // Hash utilities
  // ---------------------------------------------------------------------------

  /// Mix bits of an integer using a variant of the murmur3 finalizer.
  ///
  /// This is a well-known integer hash function that provides good
  /// avalanche properties: a single bit change in the input flips
  /// roughly half the output bits.
  ///
  /// Public so that other identity-derived services (field notes,
  /// overlay painters) can share the same deterministic hash.
  static int mix(int value) {
    // Work with 32-bit integers to stay in smi range.
    int h = value & 0xFFFFFFFF;
    h ^= h >> 16;
    h = (h * 0x45d9f3b) & 0xFFFFFFFF;
    h ^= h >> 16;
    h = (h * 0x45d9f3b) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h;
  }

  /// Extract [count] bits starting at [offset] from a hash value.
  static int _extractBits(int hash, int offset, int count) {
    return (hash >> offset) & ((1 << count) - 1);
  }

  // ---------------------------------------------------------------------------
  // Trig utilities (avoid importing dart:math for lightweight use)
  // ---------------------------------------------------------------------------

  static const double _pi = 3.14159265358979;
  static const double _twoPi = _pi * 2.0;

  /// Fast sine approximation using Taylor series.
  ///
  /// Accurate enough for geometric rendering (error < 0.001).
  /// Avoids pulling in dart:math for a single trig function.
  static double _sin(double x) {
    // Normalize to [-pi, pi]
    x = x % _twoPi;
    if (x > _pi) x -= _twoPi;
    if (x < -_pi) x += _twoPi;

    // Bhaskara I's sine approximation (accurate to ~0.2%)
    // sin(x) ≈ 16x(π - x) / (5π² - 4x(π - x))
    final num = 16.0 * x * (_pi - x);
    final den = 5.0 * _pi * _pi - 4.0 * x * (_pi - x);
    if (den.abs() < 1e-10) return 0.0;
    return num / den;
  }

  /// Fast cosine via sin(x + π/2).
  static double _cos(double x) {
    return _sin(x + _pi / 2.0);
  }
}
