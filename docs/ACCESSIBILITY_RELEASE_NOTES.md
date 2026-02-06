# Appearance & Accessibility Settings

## Overview

Socialmesh now includes a comprehensive Appearance & Accessibility settings screen that gives you full control over how the app looks and feels. These settings are designed to make Socialmesh comfortable for everyone, regardless of visual preferences or accessibility needs.

All changes apply instantly with a live preview, and your preferences are saved locally for offline-first operation.

## Features

### Font Selection

Choose the font that works best for you:

- **Branded (Default)**: JetBrainsMono - Our signature monospace font with a technical, sci-fi aesthetic
- **System**: Your device's default font for maximum familiarity and compatibility
- **Accessibility**: Inter - A highly readable font optimized for accessibility and clarity

### Text Size

Adjust text size to your comfort level:

- **System Default**: Follows your device's accessibility settings
- **Default**: Optimized baseline for Socialmesh (1.0x)
- **Large**: 15% larger text for improved readability (1.15x)
- **Extra Large**: 30% larger text for maximum visibility (1.3x)

Text scaling includes built-in guardrails to prevent layout breakage. The maximum scale is capped at 1.5x to ensure all screens remain functional.

### Display Density

Control spacing and touch target sizes:

- **Compact**: Denser UI with more content visible, smaller touch targets (44pt minimum)
- **Comfortable (Default)**: Balanced spacing with standard touch targets (48pt)
- **Large Touch**: Bigger tap targets and generous spacing for easier interaction (56pt minimum)

### High Contrast Mode

Enable enhanced visibility with:

- Pure white/black text for maximum contrast
- More visible borders and dividers
- Enhanced card outlines
- Improved focus indicators

### Reduce Motion

For users sensitive to motion or animations:

- Disables all non-essential animations
- Transitions become instant
- Reduces visual distraction
- Helps prevent motion-triggered discomfort

## How to Access

1. Open Settings from the main menu
2. Scroll to the "Appearance" section
3. Tap "Appearance & Accessibility"
4. Adjust settings using the live preview to see changes instantly

## Restoring Defaults

If you want to return to the recommended settings:

1. Tap the refresh icon in the top-right corner, or
2. Scroll to the bottom and tap "Reset to Recommended"
3. Confirm the reset in the dialog

The reset button is always visible as an escape hatch, even if text scaling makes the UI difficult to navigate.

## Technical Details

### Persistence

All accessibility preferences are stored locally using SharedPreferences. No cloud sync is required, and settings are available immediately on app startup.

### Safe Defaults Policy

- Default font: Branded (JetBrainsMono)
- Default text scale: 1.0x (Socialmesh Default)
- Default density: Comfortable
- Default contrast: Normal
- Default motion: All animations enabled

### Layout Safety

Text scaling is clamped between 0.8x and 1.5x to prevent:

- Text overflow in fixed-width elements
- Button text clipping
- Layout constraint violations
- Unreadable compressed text

### Accessibility Commitment

Socialmesh is committed to being usable by everyone. These controls are just the beginning. We believe that accessibility is not a feature but a fundamental aspect of good software design. If you encounter any accessibility issues or have suggestions for improvement, please open an issue on our GitHub repository.

## For Developers

### Using Accessibility-Aware Widgets

Replace standard animated widgets with accessibility-aware versions:

```dart
// Instead of AnimatedContainer
AccessibleAnimatedContainer(
  duration: Duration(milliseconds: 200),
  child: content,
)

// Instead of AnimatedOpacity
AccessibleAnimatedOpacity(
  opacity: 0.5,
  duration: Duration(milliseconds: 200),
  child: content,
)
```

### Enforcing Minimum Tap Targets

Wrap small interactive elements:

```dart
AccessibleTapTarget(
  onTap: () => handleTap(),
  semanticLabel: 'Add item',
  child: Icon(Icons.add, size: 20),
)
```

### Reading Preferences in Context

```dart
// Check if reduce motion is enabled
if (context.reduceMotion) {
  // Skip animation
}

// Get scaled spacing
final padding = context.scaledSpacing(16.0);

// Get animation duration respecting preferences
final duration = context.animationDuration(Duration(milliseconds: 200));
```

### Provider Access

```dart
// Watch preferences reactively
final prefs = ref.watch(accessibilityPreferencesProvider);

// Check individual settings
final reduceMotion = ref.watch(reduceMotionEnabledProvider);
final highContrast = ref.watch(highContrastEnabledProvider);
final fontFamily = ref.watch(effectiveFontFamilyProvider);
```
