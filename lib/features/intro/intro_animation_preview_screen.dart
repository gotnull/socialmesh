// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'intro_screen.dart';

/// Full-screen preview of intro animations with navigation controls.
class IntroAnimationPreviewScreen extends StatefulWidget {
  const IntroAnimationPreviewScreen({super.key});

  @override
  State<IntroAnimationPreviewScreen> createState() =>
      _IntroAnimationPreviewScreenState();
}

class _IntroAnimationPreviewScreenState
    extends State<IntroAnimationPreviewScreen> {
  int _currentIndex = 0;
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    final animationType = IntroAnimationType.values[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -100) {
            _nextAnimation();
          } else if (details.primaryVelocity! > 100) {
            _previousAnimation();
          }
        },
        child: Stack(
          children: [
            // Animation
            Positioned.fill(child: buildIntroAnimation(animationType)),

            // Controls overlay
            if (_showControls) ...[
              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded),
                  color: Colors.white,
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                ),
              ),

              // Animation name
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getAnimationName(animationType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Navigation arrows
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _previousAnimation,
                    icon: const Icon(Icons.chevron_left_rounded, size: 40),
                    color: Colors.white70,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _nextAnimation,
                    icon: const Icon(Icons.chevron_right_rounded, size: 40),
                    color: Colors.white70,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                    ),
                  ),
                ),
              ),

              // Counter
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar
                        SizedBox(
                          width: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value:
                                  (_currentIndex + 1) /
                                  IntroAnimationType.values.length,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.accentColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_currentIndex + 1} / ${IntroAnimationType.values.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _nextAnimation() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = (_currentIndex + 1) % IntroAnimationType.values.length;
    });
  }

  void _previousAnimation() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + IntroAnimationType.values.length) %
          IntroAnimationType.values.length;
    });
  }

  String _getAnimationName(IntroAnimationType type) {
    return switch (type) {
      // Original set
      IntroAnimationType.meshNetwork => 'Mesh Network',
      IntroAnimationType.radioWave => 'Radio Wave',
      IntroAnimationType.circuitTrace => 'Circuit Trace',
      IntroAnimationType.particleField => 'Particle Field',
      IntroAnimationType.radarSweep => 'Radar Sweep',
      IntroAnimationType.glitchReveal => 'Glitch Reveal',
      IntroAnimationType.hexGrid => 'Hex Grid',
      IntroAnimationType.dataStream => 'Data Stream',
      IntroAnimationType.orbitalRings => 'Orbital Rings',
      IntroAnimationType.warpTunnel => 'Warp Tunnel',
      // Demoscene style
      IntroAnimationType.plasmaWave => 'Plasma Wave',
      IntroAnimationType.starfield => 'Starfield',
      IntroAnimationType.rasterBars => 'Raster Bars',
      IntroAnimationType.copperBars => 'Copper Bars',
      IntroAnimationType.voxelLandscape => 'Voxel Landscape',
      IntroAnimationType.vectorBalls => 'Vector Balls',
      IntroAnimationType.fireEffect => 'Fire Effect',
      IntroAnimationType.rotozoom => 'Rotozoom',
      IntroAnimationType.checkerTunnel => 'Checker Tunnel',
      // New animations
      IntroAnimationType.boingBall => 'Boing Ball',
      IntroAnimationType.moirePattern => 'Moiré Pattern',
      IntroAnimationType.cubeField => 'Cube Field',
      IntroAnimationType.spiralTunnel => 'Spiral Tunnel',
      IntroAnimationType.lissajousCurves => 'Lissajous Curves',
      IntroAnimationType.pulseWave => 'Pulse Wave',
      IntroAnimationType.matrixRain => 'Matrix Rain',
      IntroAnimationType.dnaHelix => 'DNA Helix',
      IntroAnimationType.metaballs => 'Metaballs',
      IntroAnimationType.kaleidoscope => 'Kaleidoscope',
      IntroAnimationType.fractalTree => 'Fractal Tree',
      IntroAnimationType.electricArc => 'Electric Arc',
      IntroAnimationType.waveform => 'Waveform',
      IntroAnimationType.scanline => 'CRT Scanline',
      IntroAnimationType.neonGrid => 'Neon Grid',
      IntroAnimationType.vortex => 'Vortex',
      IntroAnimationType.morphingShapes => 'Morphing Shapes',
      IntroAnimationType.particleExplosion => 'Particle Explosion',
      IntroAnimationType.nebula => 'Nebula',
      IntroAnimationType.hologram => 'Hologram',
      IntroAnimationType.torus => 'Torus',
      IntroAnimationType.spectrum => 'Spectrum',
      IntroAnimationType.honeycomb => 'Honeycomb',
      IntroAnimationType.fractalZoom => 'Fractal Zoom',
      IntroAnimationType.oscilloscope => 'Oscilloscope',
      // Epic movie/game style
      IntroAnimationType.mode7Racing => 'Mode 7 Racing',
      IntroAnimationType.predatorThermal => 'Predator Thermal',
      IntroAnimationType.aliensTracker => 'Aliens Tracker',
      IntroAnimationType.cyberCorridor => 'Cyber Corridor',
      IntroAnimationType.wormhole => 'Wormhole',
      IntroAnimationType.polygonCubes => 'Polygon Cubes',
      IntroAnimationType.duneSandworm => 'Dune Sandworm',
      IntroAnimationType.bladeRunner => 'Blade Runner',
      IntroAnimationType.spaceBattle => 'Space Battle',
      IntroAnimationType.xenomorph => 'Xenomorph',
      // Outside-the-box animations
      IntroAnimationType.inkBleed => 'Ink Bleed',
      IntroAnimationType.ferrofluid => 'Ferrofluid',
      IntroAnimationType.bacteriaColony => 'Bacteria Colony',
      IntroAnimationType.cymatics => 'Cymatics',
      IntroAnimationType.auroraBorealis => 'Aurora Borealis',
      IntroAnimationType.neuralPulse => 'Neural Pulse',
      IntroAnimationType.gravityLens => 'Gravity Lens',
      IntroAnimationType.topography => 'Topography',
      IntroAnimationType.crystalGrowth => 'Crystal Growth',
      IntroAnimationType.soundWave3D => 'Sound Wave 3D',
      IntroAnimationType.bioluminescent => 'Bioluminescent',
      IntroAnimationType.datamosh => 'Datamosh',
      IntroAnimationType.magneticField => 'Magnetic Field',
      IntroAnimationType.soapBubble => 'Soap Bubble',
      IntroAnimationType.pendulumWave => 'Pendulum Wave',
      IntroAnimationType.reactionDiffusion => 'Reaction Diffusion',
      IntroAnimationType.voronoi => 'Voronoi',
      IntroAnimationType.escher => 'Escher',
      IntroAnimationType.lichtenberg => 'Lichtenberg',
      IntroAnimationType.interference => 'Interference',
      // Impossible 3D shapes
      IntroAnimationType.penroseStairs => 'Penrose Stairs',
      IntroAnimationType.impossibleCube => 'Impossible Cube',
      IntroAnimationType.blivet => 'Blivet',
      IntroAnimationType.freemishCrate => 'Freemish Crate',
      IntroAnimationType.kleinBottle => 'Klein Bottle',
      IntroAnimationType.mobiusStrip => 'Möbius Strip',
    };
  }
}
