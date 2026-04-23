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

### Optional number inputs (eye tracking)

These are best-effort — the home hero mounts the full state machine
even if they're missing, logs once via `AppLogging.pet(...)`, and keeps
eyes in the idle-forward pose. The mapping policy lives in
`lib/features/pet/services/pet_look_target.dart` (widget-level only —
raw pointer coordinates never cross into the Rive layer).

| Name | Range | Semantics |
|---|---|---|
| `lookX` | 0..100 | Eye horizontal gaze. 50 = look forward; 0 = fully left; 100 = fully right. Designer should route to pupil/iris X offset with a deadzone around 50 for "forward". |
| `lookY` | 0..100 | Eye vertical gaze. 50 = look forward; 0 = fully up; 100 = fully down. |

Behaviour rules enforced by the widget:

- **content** — full 0..100 range follows the local pointer, smoothly eased.
- **calling** — slightly stronger range (more alert).
- **sick** — reduced range + slower ease (sluggish).
- **sleeping** / **dormant** — tracking suppressed, target held at 50/50.
- On pointer release / hover exit, eyes ease back to 50/50.

Blink cadence is authored inside the state machine (not driven from
Dart) — natural idle timing in the content/calling/sick states,
closed-eye pose when `isAsleep` is `true` or `stageIndex == 5` (dormant).

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
