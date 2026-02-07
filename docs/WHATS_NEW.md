# What's New System

Guide for adding versioned "What's New" popups and drawer NEW indicators.

---

## Overview

The What's New system shows a modal bottom sheet once per version when the app introduces notable features. It also drives NEW chip indicators in the drawer menu and a dot badge on the hamburger menu button.

Key components:

- `lib/core/whats_new/whats_new_registry.dart` — Static data: payloads and items.
- `lib/providers/whats_new_providers.dart` — Riverpod state: pending payload, unseen badge keys, session tracking.
- `lib/core/whats_new/whats_new_sheet.dart` — UI: modal bottom sheet with Ico mascot.
- `lib/utils/version_compare.dart` — Semantic version parsing and comparison.

---

## How It Works

1. On app launch, `WhatsNewNotifier` loads the last-seen version from SharedPreferences and the current app version from `package_info_plus`.
2. `WhatsNewRegistry.getPendingPayload()` finds the most recent payload that is newer than `lastSeenVersion` and at most `currentVersion`.
3. If a pending payload exists, `WhatsNewSheet.showIfNeeded()` presents it once per session after the first frame.
4. The user dismisses the sheet (tap "Got it", swipe down, or tap outside). The popup version is persisted to SharedPreferences so the sheet does not reappear.
5. Badge keys persist independently of popup dismissal. Drawer items with a matching `whatsNewBadgeKey` continue to show a NEW chip and dot badge until the user navigates to that feature.
6. The hamburger menu button shows a gradient dot indicator when any unseen badge keys exist.

---

## Badge Key Lifecycle

Badge keys are decoupled from popup dismissal. This ensures the user sees NEW indicators in the drawer even after closing the What's New sheet.

| Event | Popup | Badge Keys |
|-------|-------|------------|
| App launch with new version | Shown once | Computed from registry, merged into persisted set |
| User dismisses popup | `lastSeenVersion` saved, popup gone | Unchanged — still active |
| User opens drawer | N/A | NEW chip and dot visible on matching items |
| User taps drawer item with badge key | N/A | `dismissBadgeKey()` called, key removed and persisted |
| All badge keys dismissed | N/A | Hamburger dot disappears |

---

## Adding a New What's New Entry

### 1. Add the payload to the registry

Open `lib/core/whats_new/whats_new_registry.dart` and append a new `WhatsNewPayload` to the `_payloads` list. Payloads must be in ascending version order.

```dart
static const List<WhatsNewPayload> _payloads = [
  // ... existing entries ...

  // v1.3.0 — Example new feature
  WhatsNewPayload(
    version: '1.3.0',
    headline: "What's New in Socialmesh",
    subtitle: 'Version 1.3.0',
    items: [
      WhatsNewItem(
        id: 'my_feature_intro',
        title: 'My Feature',
        description:
            'Explain what the feature does, where to find it, '
            'and why it matters to the user.',
        icon: Icons.rocket_launch,
        iconColor: Color(0xFF4CAF50),       // optional
        deepLinkRoute: '/my-feature',        // optional — renders CTA button
        helpTopicId: 'my_feature_overview',  // optional — renders "Learn more"
        badgeKey: 'my_feature',              // optional — drives drawer NEW chip
        ctaLabel: 'Try It',                  // optional — defaults to "Open"
      ),
    ],
  ),
];
```

### 2. Handle the deep link (if any)

If the item has a `deepLinkRoute`, add a case in `_WhatsNewItemCard._handleDeepLink()` inside `lib/core/whats_new/whats_new_sheet.dart`:

```dart
if (item.deepLinkRoute == '/my-feature') {
  Navigator.of(navContext).push(
    MaterialPageRoute<void>(builder: (_) => const MyFeatureScreen()),
  );
}
```

The same route mapping is used by `_handleLearnMore()`, which navigates to the feature screen and then starts the Ico help tour so the `HelpTourController` on that screen can render it.

### 3. Add the help topic (if any)

If referencing a `helpTopicId`, make sure the corresponding `HelpTopic` exists in `lib/core/help/help_content.dart` and is registered in `HelpContent.allTopics`.

The "Learn more" button:
1. Closes the What's New sheet.
2. Navigates to the feature screen (using the same `deepLinkRoute`).
3. Resets and starts the Ico help tour after a short delay so the destination screen's `HelpTourController` picks it up.

This means the help tour renders correctly on the feature screen rather than on the screen behind the popup.

---

## Attaching a Badge Key to a Drawer Item

To show a NEW chip and dot badge on a drawer menu item:

### 1. Set `whatsNewBadgeKey` on the drawer item

In `lib/features/navigation/main_shell.dart`, find the `_DrawerMenuItem` for your feature and add the `whatsNewBadgeKey` field:

```dart
_DrawerMenuItem(
  icon: Icons.rocket_launch,
  label: 'My Feature',
  screen: const MyFeatureScreen(),
  iconColor: Colors.green.shade400,
  whatsNewBadgeKey: 'my_feature',  // must match the item's badgeKey
),
```

### 2. Ensure the badge key matches

The `whatsNewBadgeKey` on the drawer item must exactly match the `badgeKey` on the `WhatsNewItem` in the registry. When the key is in the unseen set, the drawer builder watches `whatsNewUnseenBadgeKeysProvider` and sets `showNewChip: true` on the tile.

### 3. Behavior

- The NEW chip (gradient pill with "NEW" text) appears next to the item label.
- A small gradient dot appears on the item icon (when no count badge is already showing).
- Both indicators persist until the user taps the drawer item, which calls `dismissBadgeKey()`.
- The hamburger menu button shows a gradient dot when any unseen badge keys remain (and no numeric badge count is showing).

---

## Hamburger Menu Badge

The `HamburgerMenuButton` widget watches `whatsNewHasUnseenProvider`. When true (and no admin/activity count badge is showing), a small gradient dot (magenta-to-purple) appears on the hamburger icon, signaling to the user that new features are available in the drawer.

The dot disappears once all badge keys have been dismissed by visiting the corresponding features.

---

## Preference Storage

| Key | Type | Description |
|-----|------|-------------|
| `whatsNew.lastSeenVersion` | `String` | Semantic version of the last dismissed What's New popup |
| `whatsNew.featureBadgeKeys` | `List<String>` | Badge keys for new features the user has not yet visited |

Both keys are stored via `SharedPreferences`. No migration is needed when adding new payloads — new badge keys from pending payloads are automatically merged into the persisted set on load.

---

## Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `whatsNewProvider` | `NotifierProvider<WhatsNewNotifier, WhatsNewState>` | Central state for popup and badge keys |
| `whatsNewUnseenBadgeKeysProvider` | `Provider<Set<String>>` | Unseen badge keys set (for drawer rebuilds) |
| `whatsNewHasUnseenProvider` | `Provider<bool>` | Whether any unseen badge keys exist (for hamburger dot) |

---

## Testing

Tests live in:

- `test/utils/version_compare_test.dart` — Semantic version parsing and comparison.
- `test/services/whats_new_service_test.dart` — Registry logic, state transitions, badge key resolution, and data integrity.

Run them with:

```
flutter test test/utils/version_compare_test.dart test/services/whats_new_service_test.dart
```

---

## Extensibility Notes

The data model and service are designed for future expansion:

- **Protocol filtering**: Add a `protocol` field to `WhatsNewItem` and filter in `getPendingPayload()`.
- **User segmentation**: Add `isFirstInstall` / `isUpgrade` flags and filter items accordingly.
- **Feature flags**: Gate items behind remote config values before including them in the payload.
- **Multiple payloads per version**: The registry already supports multiple items per payload. For showing multiple version catch-up entries, extend `getPendingPayload()` to return a list.
- **Time-based badge expiry**: Add a `badgeExpiresAt` field to auto-dismiss badges after a period.

These extensions require no schema changes to the preference storage — only additions to the data model and filtering logic.