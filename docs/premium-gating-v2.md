# Premium Gating v2 Specification

## Overview

Premium features must be **visible, explainable, and teasing, but NOT usable** without purchase. This document defines the strict rules for premium gating across all surfaces.

## Audit Results

### Current Implementation Issues

| Surface         | File                                                     | Current Behavior                                                                           | Problem                                                                                        |
| --------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| **Ringtones**   | `lib/features/settings/ringtone_screen.dart`             | Library browsing gated by `checkPremiumOrShowUpsell()`, custom presets can be added freely | Users can add/save custom ringtone presets without premium - premium only gates library search |
| **IFTTT**       | `lib/features/settings/ifttt_config_screen.dart`         | Premium check only on save when `_enabled=true`                                            | Users can configure everything, only blocked when saving enabled config. No explanatory card.  |
| **Widgets**     | `lib/features/widget_builder/widget_builder_screen.dart` | No premium gating in builder itself                                                        | Users can create/edit widgets freely, only dashboard shows upsell card                         |
| **Automations** | `lib/features/automations/automation_editor_screen.dart` | Premium check only on save for new automations, editing allowed                            | "Save now, activate later" pattern - users can configure premium features fully                |
| **Themes**      | `lib/features/settings/theme_settings_screen.dart`       | Premium check on color selection                                                           | Acceptable - blocks at point of use                                                            |

### Existing Gating Components

| Component                    | File                                         | Purpose                                 | Issues                                   |
| ---------------------------- | -------------------------------------------- | --------------------------------------- | ---------------------------------------- |
| `PremiumFeatureGate`         | `lib/features/settings/premium_widgets.dart` | Shows locked card when feature missing  | Blocks entire content, not read-only     |
| `PremiumBadge`               | `lib/core/widgets/premium_feature_gate.dart` | Small star badge                        | Good, keep as-is                         |
| `PremiumChip`                | `lib/core/widgets/premium_feature_gate.dart` | "PREMIUM" label chip                    | Good, keep as-is                         |
| `PremiumUpsellSheet`         | `lib/core/widgets/premium_upsell_sheet.dart` | Bottom sheet with benefits and purchase | Says "config is saved" - breaks our rule |
| `checkPremiumOrShowUpsell()` | `lib/core/widgets/premium_feature_gate.dart` | Utility to check and show upsell        | Good foundation                          |

---

## Gating Rules

### Core Principle: Read-Only Preview

Premium content is **always visible** but **never actionable** until unlocked.

### What "Read-Only" Means

1. **Visible**: UI elements render normally with content
2. **Explainable**: Clear indication of what the feature does and why it's valuable
3. **Disabled**: All interactive controls (toggles, buttons, inputs) are disabled
4. **Locked indicators**: Lock icons on disabled controls
5. **Tap behavior**: Tapping any disabled control opens PremiumInfoSheet

### Disabled Actions by Surface

#### Ringtones (PremiumFeature.customRingtones)

| Action                              | Free User                        | Premium User |
| ----------------------------------- | -------------------------------- | ------------ |
| Browse built-in presets             | ✅ Allowed                       | ✅ Allowed   |
| Play any ringtone                   | ✅ Allowed                       | ✅ Allowed   |
| View library UI                     | ✅ Allowed (with preview banner) | ✅ Allowed   |
| **Search library**                  | ❌ Disabled + lock               | ✅ Allowed   |
| **Select from library**             | ❌ Disabled + lock               | ✅ Allowed   |
| **Add custom preset**               | ❌ Disabled + lock               | ✅ Allowed   |
| **Save to device** (library/custom) | ❌ Disabled + lock               | ✅ Allowed   |
| Save built-in preset to device      | ✅ Allowed                       | ✅ Allowed   |

#### IFTTT (PremiumFeature.iftttIntegration)

| Action                  | Free User                    | Premium User           |
| ----------------------- | ---------------------------- | ---------------------- |
| View explanation card   | ✅ Shown prominently         | ✅ Hidden or collapsed |
| View sample connections | ✅ Shown as examples         | ✅ Real connections    |
| **Enable IFTTT toggle** | ❌ Disabled + lock           | ✅ Allowed             |
| **Enter webhook key**   | ❌ Disabled + lock           | ✅ Allowed             |
| **Configure triggers**  | ❌ Disabled + lock (visible) | ✅ Allowed             |
| **Save configuration**  | ❌ Disabled + lock           | ✅ Allowed             |
| **Test webhook**        | ❌ Disabled + lock           | ✅ Allowed             |

#### Widgets (PremiumFeature.homeWidgets)

| Action                       | Free User              | Premium User |
| ---------------------------- | ---------------------- | ------------ |
| View My Widgets list         | ✅ With preview banner | ✅ Allowed   |
| View marketplace             | ✅ Allowed             | ✅ Allowed   |
| Preview widget appearance    | ✅ Allowed             | ✅ Allowed   |
| **Create new widget**        | ❌ Disabled + lock     | ✅ Allowed   |
| **Edit existing widget**     | ❌ Disabled + lock     | ✅ Allowed   |
| **Delete widget**            | ❌ Disabled + lock     | ✅ Allowed   |
| **Install from marketplace** | ❌ Disabled + lock     | ✅ Allowed   |
| **Add to dashboard**         | ❌ Disabled + lock     | ✅ Allowed   |
| **Reorder dashboard**        | ❌ Disabled + lock     | ✅ Allowed   |

#### Automations (PremiumFeature.automations)

| Action                           | Free User                 | Premium User |
| -------------------------------- | ------------------------- | ------------ |
| View automations list            | ✅ With preview banner    | ✅ Allowed   |
| View automation details          | ✅ Read-only preview mode | ✅ Allowed   |
| View templates                   | ✅ Allowed                | ✅ Allowed   |
| View trigger/action descriptions | ✅ Allowed                | ✅ Allowed   |
| **Create automation**            | ❌ Opens preview mode     | ✅ Allowed   |
| **Edit automation**              | ❌ Preview mode only      | ✅ Allowed   |
| **Enable/disable automation**    | ❌ Disabled + lock        | ✅ Allowed   |
| **Delete automation**            | ❌ Disabled + lock        | ✅ Allowed   |
| **Save automation**              | ❌ Disabled + lock        | ✅ Allowed   |

---

## Tap Behavior Rules

### Disabled Control Tap → PremiumInfoSheet

When a user taps ANY disabled/locked control:

1. **DO NOT** perform the action
2. **DO NOT** show an error message
3. **DO** open PremiumInfoSheet immediately
4. **DO** provide haptic feedback (light)

### PremiumInfoSheet Contents

```
┌─────────────────────────────────────┐
│ [Handle bar]                        │
│                                     │
│        ⭐ [Feature Icon]            │
│                                     │
│      [Feature Name]                 │
│                                     │
│  [1-2 sentence benefit statement]   │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ ✓ Benefit 1                     ││
│  │ ✓ Benefit 2                     ││
│  │ ✓ Benefit 3                     ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │  ⭐ Unlock for $X.XX            ││ ← Primary CTA
│  └─────────────────────────────────┘│
│                                     │
│     One-time purchase • Yours forever│
│                                     │
│        Restore Purchases            │ ← Secondary
│                                     │
│          Not now                    │ ← Tertiary (close)
│                                     │
└─────────────────────────────────────┘
```

---

## Upgrade Flow Return Behavior

### After Purchase Success

1. Dismiss PremiumInfoSheet with `pop(true)`
2. Show success snackbar: "✓ [Feature Name] unlocked!"
3. **Immediately update UI** - provider rebuilds reactively
4. User returns to same screen with controls now enabled
5. User can perform the action they originally attempted

### After Restore Success

1. Same as purchase success if feature was restored
2. If feature not in restored purchases: "No purchases found to restore"

### After Cancel/Dismiss

1. Dismiss sheet with `pop(false)`
2. User returns to same screen
3. Controls remain disabled
4. **No partial state saved** - nothing to "continue later"

---

## Analytics Events

Track these events for conversion optimization:

| Event                        | Parameters                                  | When                            |
| ---------------------------- | ------------------------------------------- | ------------------------------- |
| `premium_preview_viewed`     | `feature`, `surface`                        | User sees premium-gated content |
| `premium_locked_tapped`      | `feature`, `control`, `surface`             | User taps disabled control      |
| `premium_sheet_opened`       | `feature`, `surface`                        | PremiumInfoSheet shown          |
| `premium_sheet_dismissed`    | `feature`, `action` (upgrade/restore/close) | Sheet closed                    |
| `premium_purchase_started`   | `feature`, `product_id`                     | Purchase flow initiated         |
| `premium_purchase_completed` | `feature`, `product_id`                     | Purchase successful             |
| `premium_restore_started`    | `feature`                                   | Restore initiated               |
| `premium_restore_completed`  | `feature`, `restored` (bool)                | Restore finished                |

---

## Component API

### PremiumPreviewBanner

Shows at top of screen when in preview mode.

```dart
PremiumPreviewBanner(
  feature: PremiumFeature.automations,
  message: 'Preview Mode - Upgrade to create automations',
)
```

### LockOverlay

Wraps any widget to show lock indicator and intercept taps.

```dart
LockOverlay(
  feature: PremiumFeature.widgets,
  enabled: !hasPremium,  // Show lock when true
  child: MyEditableWidget(),
)
```

### DisabledControlWithLock

For specific controls (buttons, toggles, inputs).

```dart
DisabledControlWithLock(
  feature: PremiumFeature.iftttIntegration,
  enabled: hasPremium,
  child: Switch(value: _enabled, onChanged: _setEnabled),
)
```

### PremiumInfoSheet (Updated)

Remove "your configuration is saved" message. Add "Not now" close option.

---

## Implementation Checklist

### Phase 1: Components

- [ ] Create `PremiumPreviewBanner` widget
- [ ] Create `LockOverlay` widget
- [ ] Create `DisabledControlWithLock` widget
- [ ] Update `PremiumInfoSheet` - remove "saved" message, add "Not now"
- [ ] Update `PremiumUpsellSheet` - same changes

### Phase 2: Ringtones

- [ ] Add premium gate to "Add Custom" button
- [ ] Add premium gate to "Save to Device" when source is library/custom
- [ ] Add preview banner to library browser
- [ ] Add lock to search field

### Phase 3: IFTTT

- [ ] Add explanation card above config (visible when locked)
- [ ] Wrap all config controls in `DisabledControlWithLock`
- [ ] Show sample connections when locked
- [ ] Disable save/test buttons when locked

### Phase 4: Widgets

- [ ] Add preview banner to widget list when locked
- [ ] Wrap create/edit/delete buttons in lock overlay
- [ ] Make dashboard read-only when locked (no reorder/add/remove)
- [ ] Block wizard save when locked

### Phase 5: Automations

- [ ] Add preview banner to list when locked
- [ ] Implement "Preview Mode" for editor (all controls disabled)
- [ ] Block save button in preview mode
- [ ] Show upgrade CTA in preview mode
- [ ] Remove ability to toggle enable/disable when locked

### Phase 6: Tests

- [ ] Unit test: locked control → sheet opens
- [ ] Unit test: save blocked when locked
- [ ] Integration test: full automation preview flow
- [ ] Widget test: PremiumInfoSheet renders correctly

---

## Tone Guidelines

### DO

- "Unlock [feature] to [benefit]"
- "Get access to [specific capability]"
- "One-time purchase • Yours forever"

### DON'T

- "You need to upgrade to use this"
- "This feature is locked"
- "Subscribe to continue"
- Guilt-based messaging
- Urgency/scarcity tactics
