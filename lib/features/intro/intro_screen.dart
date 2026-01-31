// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'animations/aliens_tracker_animation.dart';
import 'animations/aurora_borealis_animation.dart';
import 'animations/bacteria_colony_animation.dart';
import 'animations/bioluminescent_animation.dart';
import 'animations/blade_runner_animation.dart';
import 'animations/blivet_animation.dart';
import 'animations/boing_ball_animation.dart';
import 'animations/checker_tunnel_animation.dart';
import 'animations/circuit_trace_animation.dart';
import 'animations/copper_bars_animation.dart';
import 'animations/crystal_growth_animation.dart';
import 'animations/cube_field_animation.dart';
import 'animations/cyber_corridor_animation.dart';
import 'animations/cymatics_animation.dart';
import 'animations/data_stream_animation.dart';
import 'animations/datamosh_animation.dart';
import 'animations/dna_helix_animation.dart';
import 'animations/dune_sandworm_animation.dart';
import 'animations/electric_arc_animation.dart';
import 'animations/escher_animation.dart';
import 'animations/ferrofluid_animation.dart';
import 'animations/fire_effect_animation.dart';
import 'animations/fractal_tree_animation.dart';
import 'animations/fractal_zoom_animation.dart';
import 'animations/freemish_crate_animation.dart';
import 'animations/glitch_reveal_animation.dart';
import 'animations/gravity_lens_animation.dart';
import 'animations/hex_grid_animation.dart';
import 'animations/hologram_animation.dart';
import 'animations/honeycomb_animation.dart';
import 'animations/impossible_cube_animation.dart';
import 'animations/ink_bleed_animation.dart';
import 'animations/interference_animation.dart';
import 'animations/kaleidoscope_animation.dart';
import 'animations/klein_bottle_animation.dart';
import 'animations/lichtenberg_animation.dart';
import 'animations/lissajous_curves_animation.dart';
import 'animations/magnetic_field_animation.dart';
import 'animations/matrix_rain_animation.dart';
import 'animations/mesh_network_animation.dart';
import 'animations/metaballs_animation.dart';
import 'animations/mobius_strip_animation.dart';
import 'animations/mode7_racing_animation.dart';
import 'animations/moire_pattern_animation.dart';
import 'animations/morphing_shapes_animation.dart';
import 'animations/nebula_animation.dart';
import 'animations/neon_grid_animation.dart';
import 'animations/neural_pulse_animation.dart';
import 'animations/orbital_rings_animation.dart';
import 'animations/oscilloscope_animation.dart';
import 'animations/particle_explosion_animation.dart';
import 'animations/particle_field_animation.dart';
import 'animations/pendulum_wave_animation.dart';
import 'animations/penrose_stairs_animation.dart';
import 'animations/plasma_wave_animation.dart';
import 'animations/polygon_cubes_animation.dart';
import 'animations/predator_thermal_animation.dart';
import 'animations/pulse_wave_animation.dart';
import 'animations/radar_sweep_animation.dart';
import 'animations/radio_wave_animation.dart';
import 'animations/raster_bars_animation.dart';
import 'animations/reaction_diffusion_animation.dart';
import 'animations/rotozoom_animation.dart';
import 'animations/scanline_animation.dart';
import 'animations/soap_bubble_animation.dart';
import 'animations/sound_wave_3d_animation.dart';
import 'animations/space_battle_animation.dart';
import 'animations/spectrum_animation.dart';
import 'animations/spiral_tunnel_animation.dart';
import 'animations/starfield_animation.dart';
import 'animations/topography_animation.dart';
import 'animations/torus_animation.dart';
import 'animations/vector_balls_animation.dart';
import 'animations/voronoi_animation.dart';
import 'animations/vortex_animation.dart';
import 'animations/voxel_landscape_animation.dart';
import 'animations/warp_tunnel_animation.dart';
import 'animations/waveform_animation.dart';
import 'animations/wormhole_animation.dart';
import 'animations/xenomorph_animation.dart';

/// Available intro animation types for the splash background.
enum IntroAnimationType {
  // Original set
  meshNetwork,
  radioWave,
  circuitTrace,
  particleField,
  radarSweep,
  glitchReveal,
  hexGrid,
  dataStream,
  orbitalRings,
  warpTunnel,
  // Demoscene / Cracktro style
  plasmaWave,
  starfield,
  rasterBars,
  copperBars,
  voxelLandscape,
  vectorBalls,
  fireEffect,
  rotozoom,
  checkerTunnel,
  // New animations
  boingBall,
  moirePattern,
  cubeField,
  spiralTunnel,
  lissajousCurves,
  pulseWave,
  matrixRain,
  dnaHelix,
  metaballs,
  kaleidoscope,
  fractalTree,
  electricArc,
  waveform,
  scanline,
  neonGrid,
  vortex,
  morphingShapes,
  particleExplosion,
  nebula,
  hologram,
  torus,
  spectrum,
  honeycomb,
  fractalZoom,
  oscilloscope,
  // Epic movie/game style
  mode7Racing,
  predatorThermal,
  aliensTracker,
  cyberCorridor,
  wormhole,
  polygonCubes,
  duneSandworm,
  bladeRunner,
  spaceBattle,
  xenomorph,
  // Outside-the-box animations
  inkBleed,
  ferrofluid,
  bacteriaColony,
  cymatics,
  auroraBorealis,
  neuralPulse,
  gravityLens,
  topography,
  crystalGrowth,
  soundWave3D,
  bioluminescent,
  datamosh,
  magneticField,
  soapBubble,
  pendulumWave,
  reactionDiffusion,
  voronoi,
  escher,
  lichtenberg,
  interference,
  // Impossible 3D shapes
  penroseStairs,
  impossibleCube,
  blivet,
  freemishCrate,
  kleinBottle,
  mobiusStrip,
}

/// Returns the animation widget for a given type.
/// These are continuous looping animations designed for splash backgrounds.
Widget buildIntroAnimation(IntroAnimationType type) {
  return switch (type) {
    // Original set
    IntroAnimationType.meshNetwork => const MeshNetworkAnimation(),
    IntroAnimationType.radioWave => const RadioWaveAnimation(),
    IntroAnimationType.circuitTrace => const CircuitTraceAnimation(),
    IntroAnimationType.particleField => const ParticleFieldAnimation(),
    IntroAnimationType.radarSweep => const RadarSweepAnimation(),
    IntroAnimationType.glitchReveal => const GlitchRevealAnimation(),
    IntroAnimationType.hexGrid => const HexGridAnimation(),
    IntroAnimationType.dataStream => const DataStreamAnimation(),
    IntroAnimationType.orbitalRings => const OrbitalRingsAnimation(),
    IntroAnimationType.warpTunnel => const WarpTunnelAnimation(),
    // Demoscene / Cracktro style
    IntroAnimationType.plasmaWave => const PlasmaWaveAnimation(),
    IntroAnimationType.starfield => const StarfieldAnimation(),
    IntroAnimationType.rasterBars => const RasterBarsAnimation(),
    IntroAnimationType.copperBars => const CopperBarsAnimation(),
    IntroAnimationType.voxelLandscape => const VoxelLandscapeAnimation(),
    IntroAnimationType.vectorBalls => const VectorBallsAnimation(),
    IntroAnimationType.fireEffect => const FireEffectAnimation(),
    IntroAnimationType.rotozoom => const RotozoomAnimation(),
    IntroAnimationType.checkerTunnel => const CheckerTunnelAnimation(),
    // New animations
    IntroAnimationType.boingBall => const BoingBallAnimation(),
    IntroAnimationType.moirePattern => const MoirePatternAnimation(),
    IntroAnimationType.cubeField => const CubeFieldAnimation(),
    IntroAnimationType.spiralTunnel => const SpiralTunnelAnimation(),
    IntroAnimationType.lissajousCurves => const LissajousCurvesAnimation(),
    IntroAnimationType.pulseWave => const PulseWaveAnimation(),
    IntroAnimationType.matrixRain => const MatrixRainAnimation(),
    IntroAnimationType.dnaHelix => const DnaHelixAnimation(),
    IntroAnimationType.metaballs => const MetaballsAnimation(),
    IntroAnimationType.kaleidoscope => const KaleidoscopeAnimation(),
    IntroAnimationType.fractalTree => const FractalTreeAnimation(),
    IntroAnimationType.electricArc => const ElectricArcAnimation(),
    IntroAnimationType.waveform => const WaveformAnimation(),
    IntroAnimationType.scanline => const ScanlineAnimation(),
    IntroAnimationType.neonGrid => const NeonGridAnimation(),
    IntroAnimationType.vortex => const VortexAnimation(),
    IntroAnimationType.morphingShapes => const MorphingShapesAnimation(),
    IntroAnimationType.particleExplosion => const ParticleExplosionAnimation(),
    IntroAnimationType.nebula => const NebulaAnimation(),
    IntroAnimationType.hologram => const HologramAnimation(),
    IntroAnimationType.torus => const TorusAnimation(),
    IntroAnimationType.spectrum => const SpectrumAnimation(),
    IntroAnimationType.honeycomb => const HoneycombAnimation(),
    IntroAnimationType.fractalZoom => const FractalZoomAnimation(),
    IntroAnimationType.oscilloscope => const OscilloscopeAnimation(),
    // Epic movie/game style
    IntroAnimationType.mode7Racing => const Mode7RacingAnimation(),
    IntroAnimationType.predatorThermal => const PredatorThermalAnimation(),
    IntroAnimationType.aliensTracker => const AliensTrackerAnimation(),
    IntroAnimationType.cyberCorridor => const CyberCorridorAnimation(),
    IntroAnimationType.wormhole => const WormholeAnimation(),
    IntroAnimationType.polygonCubes => const PolygonCubesAnimation(),
    IntroAnimationType.duneSandworm => const DuneSandwormAnimation(),
    IntroAnimationType.bladeRunner => const BladeRunnerAnimation(),
    IntroAnimationType.spaceBattle => const SpaceBattleAnimation(),
    IntroAnimationType.xenomorph => const XenomorphAnimation(),
    // Outside-the-box animations
    IntroAnimationType.inkBleed => const InkBleedAnimation(),
    IntroAnimationType.ferrofluid => const FerrofluidAnimation(),
    IntroAnimationType.bacteriaColony => const BacteriaColonyAnimation(),
    IntroAnimationType.cymatics => const CymaticsAnimation(),
    IntroAnimationType.auroraBorealis => const AuroraBorealisAnimation(),
    IntroAnimationType.neuralPulse => const NeuralPulseAnimation(),
    IntroAnimationType.gravityLens => const GravityLensAnimation(),
    IntroAnimationType.topography => const TopographyAnimation(),
    IntroAnimationType.crystalGrowth => const CrystalGrowthAnimation(),
    IntroAnimationType.soundWave3D => const SoundWave3DAnimation(),
    IntroAnimationType.bioluminescent => const BioluminescentAnimation(),
    IntroAnimationType.datamosh => const DatamoshAnimation(),
    IntroAnimationType.magneticField => const MagneticFieldAnimation(),
    IntroAnimationType.soapBubble => const SoapBubbleAnimation(),
    IntroAnimationType.pendulumWave => const PendulumWaveAnimation(),
    IntroAnimationType.reactionDiffusion => const ReactionDiffusionAnimation(),
    IntroAnimationType.voronoi => const VoronoiAnimation(),
    IntroAnimationType.escher => const EscherAnimation(),
    IntroAnimationType.lichtenberg => const LichtenbergAnimation(),
    IntroAnimationType.interference => const InterferenceAnimation(),
    // Impossible 3D shapes
    IntroAnimationType.penroseStairs => const PenroseStairsAnimation(),
    IntroAnimationType.impossibleCube => const ImpossibleCubeAnimation(),
    IntroAnimationType.blivet => const BlivetAnimation(),
    IntroAnimationType.freemishCrate => const FreemishCrateAnimation(),
    IntroAnimationType.kleinBottle => const KleinBottleAnimation(),
    IntroAnimationType.mobiusStrip => const MobiusStripAnimation(),
  };
}
