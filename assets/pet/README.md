# NodePet Rive assets

This directory holds the Rive `.riv` artefact used by the owner-mode
home-screen hero (`PetCreatureRive` → rive runtime). It is ignored on
every other surface (mini previews, companion cards, NodeDex rows stay
on the procedural `PetCreature` painter).

## Expected file

```
node_pet.riv
```

## State machine contract

The `.riv` MUST expose a state machine named **`NodePet`** with the
following inputs (verbatim names — the adapter looks them up by
string). Any missing input causes the widget to stay on the
`PetCreature` fallback path and log the missing names via
`AppLogging.pet(...)`.

### Number inputs

| Name | Range | Semantics |
|---|---|---|
| `stageIndex` | 0..5 | `PetStage.values.index` (egg, juvenile, adolescent, adult, elder, dormant) |
| `branchIndex` | 0..4 | `PetBranch.values.index` (unborn, luminous, steady, volatile, dimmed) |
| `moodIndex` | 0..5 | `PetMood.values.index` (content, hungry, sad, sick, sleeping, calling) |
| `symmetryClass` | 0..3 | Pentagonal / Hexagonal / Heptagonal / Octagonal body class |
| `strandConfig` | 0..2 | Monad / Dyad / Triad — only used if DNA panel maps to pet body |
| `signatureRotationDeg` | 0..359 | Seed-derived base rotation in degrees |
| `hygieneArtefactCount` | 0..3 | Number of stale-field marks to display |
| `vitality` | 0..1 | Composite-stat scalar |
| `buoyancy` | 0..1 | Idle-drift amplitude scalar |
| `auraIntensity` | 0..1 | Branch-aura brightness scalar |

### Bool inputs

| Name | Semantics |
|---|---|
| `isAsleep` | Closed eyes + Zzz behaviour |
| `isSick` | Sick-mouth + jitter |
| `isCalling` | Attention-call pulse |
| `hasAnomaly` | Seed-derived anomaly flag |

### Triggers

| Name | Fires when |
|---|---|
| `hatchTrigger` | Egg → juvenile transition |
| `actionTrigger` | Any care action with `applied` outcome |

## Authority rule

Procedural state (`PetState`, `PetCareEngine`, `PetSigilGeometry`)
stays the source of truth in Dart. The `.riv` is pure presentation —
do NOT encode stat decay, evolution thresholds, or mesh behaviour in
the state machine. See invariant I15 in
`docs/pet/NODE_PET_SYSTEM.md`.

## Feature flag

Rive-backed hero is gated by `PET_RIVE_ENABLED` env var
(independent of `PET_ENABLED`). Default off.
