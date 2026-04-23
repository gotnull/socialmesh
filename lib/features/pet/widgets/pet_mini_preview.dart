// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Compact animated pet preview for NodeDex rows and remote-node surfaces.
//
// Wraps PetCreature at a small fixed size, with an optional stale-dim
// treatment for observations older than [staleAfter].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../models/pet_public_state.dart';
import '../providers/pet_providers.dart';
import '../services/pet_repository.dart';
import 'pet_sigil_painter.dart';

/// Render a peer's cached pet observation at [size]. Returns a zero-sized
/// widget when no cache exists (so callers can drop it straight into a
/// Row without conditional logic).
class PetMiniPreview extends ConsumerWidget {
  final int nodeNum;
  final double size;
  final Duration staleAfter;

  const PetMiniPreview({
    super.key,
    required this.nodeNum,
    this.size = 36,
    this.staleAfter = const Duration(hours: 12),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(remotePetProvider(nodeNum));
    final observation = async.value;
    if (observation == null) {
      return SizedBox(width: size, height: size);
    }
    return _PetPreviewCanvas(
      size: size,
      observation: observation,
      isStale: observation.ageFrom(DateTime.now()) > staleAfter,
      mode: PetRenderMode.tiny,
    );
  }
}

/// Same renderer but takes the decoded state directly — useful for
/// screens that already have the observation (e.g. the Companion section
/// in NodeDex detail).
class PetPreviewFromState extends StatelessWidget {
  final PetPublicState state;
  final double size;
  final bool isStale;

  const PetPreviewFromState({
    super.key,
    required this.state,
    this.size = 64,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    return _PetPreviewCanvas(
      size: size,
      observation: RemotePetObservation(
        nodeNum: 0,
        state: state,
        observedAt: DateTime.now(),
      ),
      isStale: isStale,
      // Card-sized preview — richer than a list row but without the
      // home screen's interactive parallax.
      mode: PetRenderMode.card,
    );
  }
}

class _PetPreviewCanvas extends StatelessWidget {
  final double size;
  final RemotePetObservation observation;
  final bool isStale;
  final PetRenderMode mode;

  const _PetPreviewCanvas({
    required this.size,
    required this.observation,
    required this.isStale,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final s = observation.state;
    return Opacity(
      opacity: isStale ? 0.55 : 1.0,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: ColoredBox(
            color: context.card.withValues(alpha: 0.6),
            child: PetCreature(
              dnaSeed: s.dnaSeed,
              stage: s.stage,
              branch: s.branch,
              mood: s.mood,
              isAsleep: s.isAsleep,
              isSick: s.isSick,
              isCalling: s.isCalling,
              hygieneArtefactCount: 0,
              size: size,
              mode: mode,
            ),
          ),
        ),
      ),
    );
  }
}
