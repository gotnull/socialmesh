// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Built-in MorphTimeline presets. New ones are a single entry — define the
// keyframe list, register it in the registry map at the bottom, and the
// widget's `MeshMorphWidget.preset(...)` factory picks it up.

import 'mesh_shape.dart';
import 'morph_timeline.dart';

/// Stable ids for the presets. Used by callers / settings UI / telemetry
/// to refer to sequences without serialising the full keyframe list.
enum MeshMorphPresetId {
  /// Short opener for splash screens: grid → square → sphere → icosahedron.
  /// The user's "feels like the SocialMesh logo arriving" sequence.
  icosahedronJourney,

  /// Full demoscene tour through all 15 rsvpnano shapes. ~120 s cycle.
  /// Good for an "about / credits" screen or a debug toy.
  vectorballTour,

  /// Geometry-focused subset: only the regular polyhedra + sphere. Ends
  /// on the icosahedron so the brand logo is always last visible.
  platonicCircuit,

  /// Soft / surface shapes only — torus, möbius, hyperboloid, saddle,
  /// sphere. No edges drawn; reads as a flowing organic loop.
  surfaceFlow,

  /// Wireframe-only — cube, octahedron, pyramid, icosahedron. The
  /// edges-on-the-whole-time look.
  wireframeMarch,
}

class MeshMorphPresets {
  // ---- Keyframe shorthand to keep the table readable ----
  static MorphKeyframe _kf(
    MeshShapeId s, {
    Duration hold = const Duration(seconds: 4),
    Duration morph = const Duration(milliseconds: 1200),
    EaseCurve ease = EaseCurve.smoothStep,
  }) => MorphKeyframe(shape: s, hold: hold, morph: morph, ease: ease);

  /// The user-requested opener: starts as a cube grid, condenses to a
  /// tighter cube ("square"), inflates to a sphere, then unfolds into the
  /// icosahedron — ending with a long hold so the SocialMesh logo
  /// silhouette sits cleanly on the screen. Total ≈ 15 s.
  static final MorphTimeline icosahedronJourney = MorphTimeline([
    _kf(
      MeshShapeId.cube,
      hold: const Duration(milliseconds: 2200),
      morph: const Duration(milliseconds: 1400),
    ),
    // "Square" — the same cube but viewed/held as the second hero
    // silhouette. We keep the cube generator (no separate "square"
    // primitive in the rsvpnano catalog) but give it a shorter hold so
    // the eye reads "two cube poses → sphere".
    _kf(
      MeshShapeId.cube,
      hold: const Duration(milliseconds: 1400),
      morph: const Duration(milliseconds: 1400),
    ),
    _kf(
      MeshShapeId.sphere,
      hold: const Duration(milliseconds: 2400),
      morph: const Duration(milliseconds: 1600),
      ease: EaseCurve.easeOutCubic,
    ),
    _kf(
      MeshShapeId.icosahedron,
      // Long final hold so the brand silhouette settles into the
      // viewer's memory before the cycle wraps.
      hold: const Duration(seconds: 6),
      morph: const Duration(milliseconds: 1800),
      ease: EaseCurve.easeOutCubic,
    ),
  ], presetId: 'icosahedron_journey');

  /// Tour every shape in the registry. Order chosen so each transition
  /// reads cleanly (grid → sphere → ring family → wireframes → back to
  /// the icosahedron hero shape).
  static final MorphTimeline vectorballTour = MorphTimeline([
    _kf(MeshShapeId.cube),
    _kf(MeshShapeId.sphere),
    _kf(MeshShapeId.torus),
    _kf(MeshShapeId.hyperboloid),
    _kf(MeshShapeId.saddle),
    _kf(MeshShapeId.wavePlane),
    _kf(MeshShapeId.helix),
    _kf(MeshShapeId.doubleHelix),
    _kf(MeshShapeId.trefoil),
    _kf(MeshShapeId.mobius),
    _kf(MeshShapeId.lissajous),
    _kf(MeshShapeId.randomCloud),
    _kf(MeshShapeId.octahedron),
    _kf(MeshShapeId.pyramid),
    _kf(
      MeshShapeId.icosahedron,
      hold: const Duration(seconds: 6),
      morph: const Duration(milliseconds: 1600),
    ),
  ], presetId: 'vectorball_tour');

  /// Only the geometry darlings — cube, octahedron, sphere, icosahedron.
  /// Reads as "platonic solids of progressively higher symmetry" with the
  /// icosahedron as the climax.
  static final MorphTimeline platonicCircuit = MorphTimeline([
    _kf(
      MeshShapeId.cube,
      hold: const Duration(seconds: 3),
      morph: const Duration(milliseconds: 1200),
    ),
    _kf(
      MeshShapeId.octahedron,
      hold: const Duration(seconds: 3),
      morph: const Duration(milliseconds: 1200),
    ),
    _kf(
      MeshShapeId.sphere,
      hold: const Duration(seconds: 3),
      morph: const Duration(milliseconds: 1200),
      ease: EaseCurve.easeOutCubic,
    ),
    _kf(
      MeshShapeId.icosahedron,
      hold: const Duration(seconds: 5),
      morph: const Duration(milliseconds: 1400),
      ease: EaseCurve.easeOutCubic,
    ),
  ], presetId: 'platonic_circuit');

  /// All-surface, no-edges flow. Good background animation for screens
  /// where the icosahedron would feel too "brand" and the cube too
  /// "geometric".
  static final MorphTimeline surfaceFlow = MorphTimeline([
    _kf(MeshShapeId.sphere),
    _kf(MeshShapeId.torus),
    _kf(MeshShapeId.hyperboloid),
    _kf(MeshShapeId.saddle),
    _kf(MeshShapeId.mobius),
    _kf(MeshShapeId.wavePlane),
  ], presetId: 'surface_flow');

  /// All-wireframe march. Edges stay drawn throughout. Heroes the
  /// icosahedron at the end.
  static final MorphTimeline wireframeMarch = MorphTimeline([
    _kf(
      MeshShapeId.cube,
      hold: const Duration(milliseconds: 2500),
      morph: const Duration(milliseconds: 1000),
    ),
    _kf(
      MeshShapeId.octahedron,
      hold: const Duration(milliseconds: 2500),
      morph: const Duration(milliseconds: 1000),
    ),
    _kf(
      MeshShapeId.pyramid,
      hold: const Duration(milliseconds: 2500),
      morph: const Duration(milliseconds: 1000),
    ),
    _kf(
      MeshShapeId.icosahedron,
      hold: const Duration(seconds: 5),
      morph: const Duration(milliseconds: 1400),
    ),
  ], presetId: 'wireframe_march');

  static final Map<MeshMorphPresetId, MorphTimeline> _byId = {
    MeshMorphPresetId.icosahedronJourney: icosahedronJourney,
    MeshMorphPresetId.vectorballTour: vectorballTour,
    MeshMorphPresetId.platonicCircuit: platonicCircuit,
    MeshMorphPresetId.surfaceFlow: surfaceFlow,
    MeshMorphPresetId.wireframeMarch: wireframeMarch,
  };

  static MorphTimeline byId(MeshMorphPresetId id) => _byId[id]!;

  /// All registered ids in declaration order — useful for a settings
  /// picker that wants to show every available animation.
  static List<MeshMorphPresetId> get all => MeshMorphPresetId.values;
}
