// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Barrel file for the mesh-morph subsystem. Import this single file when
// using the animated morphing mesh widget; the internal modules don't
// need to be referenced directly by consumers.
//
//   import 'package:socialmesh/core/widgets/mesh_morph/mesh_morph.dart';
//
//   MeshMorphWidget.preset(
//     MeshMorphPresetId.icosahedronJourney,
//     size: 372,
//   );

export 'mesh_shape.dart'
    show
        MeshShape,
        MeshShapeId,
        Point3D,
        ShapeEdge,
        shapeById,
        meshShapeRegistry;
export 'morph_timeline.dart'
    show MorphTimeline, MorphKeyframe, EaseCurve, MorphStyle, TimelineSample;
export 'morph_presets.dart' show MeshMorphPresetId, MeshMorphPresets;
export 'mesh_morph_widget.dart' show MeshMorphWidget, MorphRotationStyle;
