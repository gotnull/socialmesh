// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetCreatureRive — owner-mode hero widget. Mounts a Rive artboard
// from `assets/pet/node_pet.riv` and drives its State Machine via the
// [PetRiveInputs] contract. Falls back to the procedural [PetCreature]
// custom painter in every failure mode:
//   - asset missing or unloadable
//   - state machine "NodePet" not present on the artboard
//   - any documented input missing (partial binding = fallback — not
//     a half-bound render)
//
// Design rules (see NODE_PET_SYSTEM.md §9.13):
//   - Procedural pet state stays authoritative in Dart.
//   - This widget is a presentation choice, not a state holder.
//   - Mini previews / companion cards / NodeDex rows NEVER use Rive.
//   - Inputs applied only when [PetRiveInputs] value differs from the
//     last-applied bundle — `==` short-circuit prevents redundant
//     writes to the state machine each animation frame.

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart';

import '../../../core/logging.dart';
import '../models/pet_enums.dart';
import '../services/pet_rive_adapter.dart';
import 'pet_sigil_painter.dart';

/// Asset path + state-machine name are centralised here so tests +
/// README can reference the same constants.
const String kPetRiveAssetPath = 'assets/pet/node_pet.riv';
const String kPetRiveStateMachineName = 'NodePet';

/// Documented inputs the state machine MUST expose (see §9.13). Each
/// is validated at controller-init time; any missing name drops the
/// widget back to the fallback [PetCreature] painter.
const List<String> kPetRiveNumberInputs = [
  'stageIndex',
  'branchIndex',
  'moodIndex',
  'symmetryClass',
  'strandConfig',
  'signatureRotationDeg',
  'hygieneArtefactCount',
  'vitality',
  'buoyancy',
  'auraIntensity',
];
const List<String> kPetRiveBoolInputs = [
  'isAsleep',
  'isSick',
  'isCalling',
  'hasAnomaly',
];
const List<String> kPetRiveTriggerInputs = ['hatchTrigger', 'actionTrigger'];

class PetCreatureRive extends StatefulWidget {
  // Fallback-mode inputs (same as PetCreature).
  final int dnaSeed;
  final PetStage stage;
  final PetBranch branch;
  final PetMood mood;
  final bool isAsleep;
  final bool isSick;
  final bool isCalling;
  final int hygieneArtefactCount;
  final double size;
  final int? energy;
  final int? moodStat;
  final int? stability;
  final int statMax;

  /// Rive-mode inputs. When null, stay on the fallback path.
  final PetRiveInputs? riveInputs;

  const PetCreatureRive({
    super.key,
    required this.dnaSeed,
    required this.stage,
    required this.branch,
    required this.mood,
    required this.isAsleep,
    required this.isSick,
    required this.isCalling,
    required this.hygieneArtefactCount,
    this.size = 220,
    this.energy,
    this.moodStat,
    this.stability,
    this.statMax = 10,
    this.riveInputs,
  });

  @override
  State<PetCreatureRive> createState() => _PetCreatureRiveState();
}

class _PetCreatureRiveState extends State<PetCreatureRive> {
  Artboard? _artboard;
  StateMachineController? _controller;
  bool _loadAttempted = false;
  bool _bindingComplete = false;
  PetRiveInputs? _lastAppliedInputs;

  @override
  void initState() {
    super.initState();
    // Don't attempt to load if the caller has no Rive bundle — that's
    // the documented signal to stay on fallback.
    if (widget.riveInputs != null) {
      unawaited(_loadAndBind());
    } else {
      _loadAttempted = true; // treat as "done, fallback".
    }
  }

  @override
  void didUpdateWidget(covariant PetCreatureRive old) {
    super.didUpdateWidget(old);
    // Apply inputs only when they actually change. The adapter's
    // value-class equality is what makes this short-circuit work.
    if (_bindingComplete && widget.riveInputs != null) {
      _maybeApply(widget.riveInputs!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadAndBind() async {
    try {
      final bytes = await rootBundle.load(kPetRiveAssetPath);
      final file = RiveFile.import(bytes);
      final artboard = file.mainArtboard.instance();
      final controller = StateMachineController.fromArtboard(
        artboard,
        kPetRiveStateMachineName,
      );
      if (controller == null) {
        AppLogging.pet(
          'PetCreatureRive: state machine '
          '"$kPetRiveStateMachineName" not found on artboard '
          '"${artboard.name}" — falling back to PetCreature',
        );
        _markLoadDone();
        return;
      }

      // Validate every documented input is present. A partially-
      // bound state machine would animate half-correctly; we'd
      // rather show the painter than a broken hero.
      final missing = _collectMissingInputs(controller);
      if (missing.isNotEmpty) {
        AppLogging.pet(
          'PetCreatureRive: .riv missing ${missing.length} required '
          'state-machine input(s): ${missing.join(", ")} — falling '
          'back to PetCreature',
        );
        controller.dispose();
        _markLoadDone();
        return;
      }

      artboard.addController(controller);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _artboard = artboard;
        _controller = controller;
        _bindingComplete = true;
        _loadAttempted = true;
      });
      if (widget.riveInputs != null) {
        _maybeApply(widget.riveInputs!);
      }
      AppLogging.pet(
        'PetCreatureRive: mounted "$kPetRiveStateMachineName" on '
        '${artboard.name} (${kPetRiveNumberInputs.length} number + '
        '${kPetRiveBoolInputs.length} bool + '
        '${kPetRiveTriggerInputs.length} trigger inputs)',
      );
    } catch (e, st) {
      AppLogging.pet(
        'PetCreatureRive: asset load/init failed ($e) — falling back '
        'to PetCreature. stack: $st',
      );
      _markLoadDone();
    }
  }

  void _markLoadDone() {
    if (!mounted) return;
    setState(() {
      _loadAttempted = true;
      _bindingComplete = false;
    });
  }

  /// Returns the names of any documented input missing on the given
  /// controller. Empty list = fully bound.
  List<String> _collectMissingInputs(StateMachineController controller) {
    final missing = <String>[];
    for (final name in kPetRiveNumberInputs) {
      if (controller.findInput<double>(name) is! SMINumber) {
        missing.add(name);
      }
    }
    for (final name in kPetRiveBoolInputs) {
      final input = controller.findInput<bool>(name);
      // A bool input may resolve as SMIBool OR SMITrigger (trigger
      // extends bool); we only want SMIBool here. Mismatches go into
      // the missing list so the designer catches typos.
      if (input is! SMIBool || input is SMITrigger) {
        missing.add(name);
      }
    }
    for (final name in kPetRiveTriggerInputs) {
      final input = controller.findInput<bool>(name);
      if (input is! SMITrigger) {
        missing.add(name);
      }
    }
    return missing;
  }

  void _maybeApply(PetRiveInputs inputs) {
    if (_controller == null) return;
    if (_lastAppliedInputs == inputs) return;
    _applyAll(inputs);
    _lastAppliedInputs = inputs;
  }

  void _applyAll(PetRiveInputs i) {
    final c = _controller!;
    _setNumber(c, 'stageIndex', i.stageIndex.toDouble());
    _setNumber(c, 'branchIndex', i.branchIndex.toDouble());
    _setNumber(c, 'moodIndex', i.moodIndex.toDouble());
    _setNumber(c, 'symmetryClass', i.symmetryClass.toDouble());
    _setNumber(c, 'strandConfig', i.strandConfig.toDouble());
    _setNumber(c, 'signatureRotationDeg', i.signatureRotationDeg.toDouble());
    _setNumber(c, 'hygieneArtefactCount', i.hygieneArtefactCount.toDouble());
    _setNumber(c, 'vitality', i.vitality);
    _setNumber(c, 'buoyancy', i.buoyancy);
    _setNumber(c, 'auraIntensity', i.auraIntensity);
    _setBool(c, 'isAsleep', i.isAsleep);
    _setBool(c, 'isSick', i.isSick);
    _setBool(c, 'isCalling', i.isCalling);
    _setBool(c, 'hasAnomaly', i.hasAnomaly);
    // Triggers are fired externally, not as part of a state-sync.
  }

  void _setNumber(StateMachineController c, String name, double value) {
    final input = c.findInput<double>(name);
    if (input is SMINumber) input.value = value;
  }

  void _setBool(StateMachineController c, String name, bool value) {
    final input = c.findInput<bool>(name);
    if (input is SMIBool && input is! SMITrigger) input.value = value;
  }

  @override
  Widget build(BuildContext context) {
    // Until load is settled OR binding failed, render the fallback.
    // This avoids a visible flicker while the asset loads.
    if (!_loadAttempted || !_bindingComplete || _artboard == null) {
      return _fallback();
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Rive(artboard: _artboard!, fit: BoxFit.contain),
    );
  }

  Widget _fallback() {
    return PetCreature(
      dnaSeed: widget.dnaSeed,
      stage: widget.stage,
      branch: widget.branch,
      mood: widget.mood,
      isAsleep: widget.isAsleep,
      isSick: widget.isSick,
      isCalling: widget.isCalling,
      hygieneArtefactCount: widget.hygieneArtefactCount,
      size: widget.size,
      energy: widget.energy,
      moodStat: widget.moodStat,
      stability: widget.stability,
      statMax: widget.statMax,
    );
  }
}
