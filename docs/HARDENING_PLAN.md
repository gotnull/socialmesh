# Codebase Hardening Plan

This document tracks the security and reliability hardening effort to eliminate crash-causing patterns.

## Executive Summary

Two crash patterns were identified:

1. **Riverpod Lifecycle Crash**: `ref.read()` called after widget disposal (ConsumerStatefulElement.\_assertNotDisposed)
2. **Image Pipeline Fatal Error**: `ImageStreamCompleter` decoding errors propagating as fatal

## Status: Phase 1 Complete

- Safety toolkit created and tested (25 tests passing)
- Pattern applied to 3 screens (profile_screen, data_export_screen, create_signal_screen)
- Error handler integrated in main.dart
- `flutter analyze` passes with zero issues

## Completed Work

### Safety Toolkit

| File                                   | Purpose                               |
| -------------------------------------- | ------------------------------------- |
| `lib/core/safety/lifecycle_mixin.dart` | LifecycleSafeMixin for safe async ops |
| `lib/core/safety/safe_image.dart`      | SafeImage widget with error handling  |
| `lib/core/safety/error_handler.dart`   | Centralized error classification      |
| `lib/core/safety/safety.dart`          | Barrel export                         |

### Screens with LifecycleSafeMixin Applied

| File                                                     | Methods Fixed                                                             |
| -------------------------------------------------------- | ------------------------------------------------------------------------- |
| `lib/features/profile/profile_screen.dart`               | \_saveProfile, \_pickAvatar, \_removeAvatar, \_pickBanner, \_removeBanner |
| `lib/features/settings/data_export_screen.dart`          | \_handleClear, \_handleClearAll                                           |
| `lib/features/signals/screens/create_signal_screen.dart` | \_getLocation                                                             |

### Infrastructure Changes

| File            | Change                             |
| --------------- | ---------------------------------- |
| `lib/main.dart` | Added AppErrorHandler.initialize() |

### Tests

| File                                                  | Tests           |
| ----------------------------------------------------- | --------------- |
| `test/core/safety/lifecycle_safety_test.dart`         | 15 widget tests |
| `test/core/safety/codebase_hardening_audit_test.dart` | 10 audit tests  |

## Pattern: LifecycleSafeMixin

### The Problem

```dart
// DANGEROUS: ref.read() after await may crash if widget disposed
Future<void> _saveProfile() async {
  await someAsyncOperation();
  ref.read(someProvider.notifier).update(data);  // CRASH
  Navigator.pop(context);  // CRASH
}
```

### The Solution

```dart
class _MyWidgetState extends ConsumerState<MyWidget>
    with LifecycleSafeMixin<MyWidget> {

  Future<void> _saveProfile() async {
    // Capture dependencies BEFORE await
    final notifier = ref.read(someProvider.notifier);

    await someAsyncOperation();
    if (!mounted) return;  // Guard after await

    notifier.update(data);  // Safe - captured before await
    safeNavigatorPop();  // Safe method from mixin
  }
}
```

### Mixin Methods

| Method                             | Purpose                          |
| ---------------------------------- | -------------------------------- |
| `safeSetState(fn)`                 | setState with mounted check      |
| `safeNavigatorPop([result])`       | Pop navigation safely            |
| `safeShowSnackBar(message, {...})` | Show snackbar safely             |
| `safeAsync<T>(fn)`                 | Execute async with mounted guard |
| `safeTimer(duration, callback)`    | Timer that respects mounted      |

## Files Still Needing LifecycleSafeMixin

The audit test identifies these screens with unsafe async patterns:

### High Priority

| File                                | Issue                                           |
| ----------------------------------- | ----------------------------------------------- |
| `canned_responses_screen.dart`      | Multiple methods need guards                    |
| `admin_follow_requests_screen.dart` | \_resetAndSeed, \_seedUsers                     |
| `ringtone_screen.dart`              | \_performSearch                                 |
| `nodes_screen.dart`                 | \_disconnectDevice                              |
| `meshcore_shell.dart`               | \_disconnect                                    |
| `create_post_screen.dart`           | \_tagNode                                       |
| `create_story_screen.dart`          | \_loadRecentAssets, \_selectAsset, \_openCamera |

## Image Safety

### Already Protected (have errorBuilder)

- `user_avatar.dart`
- `shimmer_image.dart`
- `signal_card.dart`
- `signal_thumbnail.dart`
- Most device shop screens

### May Benefit from SafeImage

The audit test tracks Image usages without errorBuilder. Current count: 20 (threshold: 30).

## AppErrorHandler

The error handler classifies errors as fatal or recoverable:

### Recoverable (logged, not crashed)

- `ImageCodecException`
- `NetworkImageLoadException`
- `HTTP request failed`
- `SocketException`
- `TimeoutException`
- `FormatException`
- `HandshakeException`
- Widget disposal errors

### Fatal (crashes app)

- `AssertionError` (except widget disposal)
- Errors without parseable message

### PII Sanitization

Automatically removes from error messages:

- Email patterns
- Phone numbers
- IP addresses
- API keys
- UUID patterns

## Migration Guide

### Adding LifecycleSafeMixin

1. Add import:

   ```dart
   import 'package:socialmesh/core/safety/lifecycle_mixin.dart';
   ```

2. Add mixin to State class:

   ```dart
   class _MyScreenState extends ConsumerState<MyScreen>
       with LifecycleSafeMixin<MyScreen> {
   ```

3. In async methods:
   - Move `ref.read()` calls BEFORE any `await`
   - Add `if (!mounted) return;` after each `await`
   - Replace `setState(...)` with `safeSetState(...)`
   - Replace `Navigator.pop(context)` with `safeNavigatorPop()`

### Using SafeImage

Replace:

```dart
Image.network(url, errorBuilder: (ctx, err, st) => placeholder)
```

With:

```dart
SafeImage.network(url, placeholder: placeholder)
```

## Test Commands

```bash
# Run safety tests
flutter test test/core/safety/

# Run all tests
flutter test

# Analyze codebase
flutter analyze
```

## Definition of Done

### Per-Screen

- [ ] Uses LifecycleSafeMixin if ConsumerStatefulWidget with async
- [ ] All provider reads captured BEFORE await
- [ ] All post-await code has mounted guards
- [ ] Uses safeSetState, safeNavigatorPop, safeShowSnackBar
- [ ] All Image.network/file have errorBuilder (or use SafeImage)

### Codebase-Level

- [x] `flutter analyze` passes with zero issues
- [x] Safety tests pass (25/25)
- [x] Error handler initialized in main.dart
- [ ] All high-priority screens converted (ongoing)
