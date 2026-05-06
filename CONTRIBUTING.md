# Contributing to SocialMesh

We welcome contributions. This document explains the rules your code must follow to be accepted. These are not suggestions — PRs that violate them will be rejected.

---

## Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes following the rules below
4. Run the full quality checklist (see [Before You Submit](#before-you-submit))
5. Commit with clear, descriptive messages
6. Push to your fork and open a Pull Request

---

## Code Quality Rules

### The Linter

SocialMesh ships a project-specific linter at `scripts/hooks/socialmesh-lint.sh`. Every modified file must pass it with zero errors before you open a PR.

```sh
# Check specific files
scripts/hooks/socialmesh-lint.sh lib/path/to/file.dart

# Check all staged files (pre-commit)
scripts/hooks/socialmesh-lint.sh

# Check all tracked files
scripts/hooks/socialmesh-lint.sh --all

# Include dart format verification
scripts/hooks/socialmesh-lint.sh --format
```

The linter enforces every rule listed below automatically. If the linter says ERROR, your PR will not be accepted. No exceptions.

### Banned Patterns

The following are hard errors. The linter will catch them, but you should know why they exist.

| Pattern                                                                             | Why it is banned                                                                                                                                              | Use instead                                                                                               |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `TODO`, `FIXME`, `HACK` comments                                                    | Untracked work rots. Implement it now or create a sprint task.                                                                                                | Remove the comment and do the work, or file an issue.                                                     |
| `// ignore:` directives                                                             | Suppressing analyzer warnings hides real problems.                                                                                                            | Fix the underlying issue. Only `lib/generated/` is exempt.                                                |
| `StateNotifier`, `StateNotifierProvider`, `StateProvider`, `ChangeNotifierProvider` | Legacy Riverpod 2.x APIs. The codebase is Riverpod 3.x only.                                                                                                  | `Notifier`, `AsyncNotifier`, `NotifierProvider`                                                           |
| `showDialog`, `AlertDialog`, `SimpleDialog`                                         | Material dialogs break the app's design language.                                                                                                             | `AppBottomSheet`, `DatePickerSheet`, `TimePickerSheet`                                                    |
| `FloatingActionButton`                                                              | Primary actions belong in the app bar, not floating over content.                                                                                             | App bar `IconButton` or `AppBarOverflowMenu`                                                              |
| `throw UnimplementedError`                                                          | Dead stubs accumulate. Ship complete code.                                                                                                                    | Implement the method or remove it.                                                                        |
| Bare `Scaffold(`                                                                    | All screens use the project's themed scaffold.                                                                                                                | `GlassScaffold` or `GlassScaffold.body`                                                                   |
| Bare `Switch(` or `Switch.adaptive(`                                                | Unstyled switches break theme consistency.                                                                                                                    | `ThemedSwitch`                                                                                            |
| `SwitchListTile(`                                                                   | Same reason.                                                                                                                                                  | `ListTile` with `ThemedSwitch` as `trailing`                                                              |
| Railway-provided domains                                                            | Infrastructure hosting domains must never appear in user-facing code.                                                                                         | `socialmesh.app` custom domains                                                                           |
| Hardcoded spacing/sizing numbers                                                    | Magic numbers make the UI inconsistent.                                                                                                                       | `AppTheme.spacing*` and `AppTheme.radius*` constants                                                      |
| `IcoHelpAppBarButton` without `HelpTourController`                                  | The help button sets tour state but without the controller wrapper the overlay never renders. The button appears to work (icon animates) but nothing happens. | Wrap the screen's `GlassScaffold` in `HelpTourController(topicId: '...', stepKeys: const {}, child: ...)` |
| `ConsumerStatefulWidget` with `await` but no `LifecycleSafeMixin`                   | Manual `mounted` checks are error-prone and inconsistent. The mixin provides `safeSetState`, `canUpdateUI`, and safe async patterns.                          | Add `with LifecycleSafeMixin<YourWidget>` to your `ConsumerState` class.                                  |
| `StreamSubscription` field without `.cancel()`                                      | Uncanceled subscriptions leak memory and fire callbacks on disposed widgets.                                                                                  | Call `_subscription?.cancel()` in `dispose()`. Every subscription field must have a matching cancel.      |

### Required Patterns

| Requirement                    | Rule                                                                                                                                                                                                                  |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **SPDX header**                | Every `.dart` file under `lib/` and `test/` must start with `// SPDX-License-Identifier: GPL-3.0-or-later`. Files under `backend/`, `docs/`, `scripts/`, `tools/`, `web/`, and `.github/` must NOT have SPDX headers. |
| **GlassScaffold**              | Every screen class (a widget whose name ends in `Screen`) must use `GlassScaffold`. If you have a legitimate exception (immersive overlay, navigation shell), add `// lint-allow: scaffold` with a reason.            |
| **TextField maxLength**        | Every `TextField` and `TextFormField` must set `maxLength`. Unbounded text inputs are a crash and abuse vector.                                                                                                       |
| **Async safety**               | After any `await`, check `mounted` before using `context`, `ref.read`, `ref.watch`, or `setState`. Use `safeSetState()` from `LifecycleSafeMixin` where possible.                                                     |
| **LifecycleSafeMixin**         | All `ConsumerStatefulWidget` classes with async operations must use `LifecycleSafeMixin`. The linter checks this per-class, not per-file.                                                                             |
| **StreamSubscription cancel**  | Every `StreamSubscription` field must have a corresponding `.cancel()` call in `dispose()`. The linter checks for the presence of `.cancel()` in any file that declares a `StreamSubscription`.                       |
| **HelpTourController pairing** | Every screen that uses `IcoHelpAppBarButton` must wrap its scaffold in `HelpTourController` with the same `topicId`. Without it the help button toggles state but the tour overlay never appears.                     |
| **Haptic feedback**            | Interactive actions using `GestureDetector` with `onTap` should provide haptic feedback via `HapticFeedback.lightImpact()` or `HapticService`. The linter warns when haptics are absent.                              |
| **Keyboard dismissal**         | Screens with text inputs must dismiss the keyboard on outside taps. Use `GestureDetector` + `FocusScope.of(context).unfocus()` or `onTapOutside` on the `TextField`. The linter warns when neither is present.        |

### Warnings vs Errors

The linter emits two severity levels:

- **ERROR** — blocks commits. These are hard rules (banned patterns, missing mixin, missing controller, missing cancel, missing SPDX header, etc.). Zero tolerance.
- **WARN** — advisory. These flag patterns that should be fixed but do not block commits. Currently: hardcoded colors, missing haptics, missing keyboard dismissal.

### Hardcoded Colors (Warning)

Do not use `Color(0xFF...)` hex literals or named `Colors.red`, `Colors.blue`, etc. in feature code. Use the project's semantic color system instead:

| Need                     | Use                                                               |
| ------------------------ | ----------------------------------------------------------------- |
| Accent-derived colors    | `context.accentColor`, `AccentColors.*`                           |
| Semantic foreground      | `SemanticColors.onAccent`, `SemanticColors.onBrand`               |
| Chart/graph colors       | `ChartColors.*`                                                   |
| Theme-aware text/surface | `context.textPrimary`, `context.card`, `context.background`, etc. |
| Status indicators        | Define constants in `lib/core/theme.dart`, not inline             |

`Colors.white`, `Colors.black`, and `Colors.transparent` are allowed everywhere. Theme files (`lib/core/theme.dart`), `CustomPainter` classes, and onboarding widgets are exempt. For legitimate edge cases, add `// lint-allow: hardcoded-color` to the file.

---

## Architecture Rules

### Protocol Isolation

Each supported protocol is a separate product. No cross-protocol logic, state, providers, or conditional branching in screens. Protocol selection happens at the root shell only. Shared code lives in `lib/core/` only.

### Riverpod 3.x Only

Use `Notifier`, `AsyncNotifier`, `Provider`, `FutureProvider`, `StreamProvider`. Legacy Riverpod 2.x APIs are banned project-wide.

### Feature Modules

Feature code lives in `lib/features/<name>/` and must be self-contained. No cross-feature imports except through shared providers in `lib/providers/`.

### Database Migrations

Existing databases: `messages.db`, `signals.db`, `packet_dedupe.db`, `routes.db`, `nodedex.db`, `traceroute.db`. Never alter existing tables or columns for live users. Always add nullable columns and bump the schema version. Never lose user data.

---

## UI Conventions

| Element             | Convention                                                          |
| ------------------- | ------------------------------------------------------------------- |
| Colors              | Use `SemanticColors` / theme extensions. No hardcoded color values. |
| Save/Submit buttons | Fixed bottom gradient button, not app bar.                          |
| App bar actions     | One primary `IconButton`, rest in `AppBarOverflowMenu`.             |
| Empty states        | Icon + headline + description + `FilledButton` action.              |
| List tiles          | No truncation. Vertical stacking. `Wrap` for metadata.              |

---

## Before You Submit

Run these checks on every file you modified. All must pass with zero issues.

```sh
# 1. Project linter (mandatory — catches all banned patterns)
scripts/hooks/socialmesh-lint.sh lib/path/to/your_file.dart

# 2. Dart formatter
dart format lib/path/to/your_file.dart

# 3. Flutter analyzer (specific files only, not project-wide)
flutter analyze lib/path/to/your_file.dart

# 4. Tests (only test files related to your changes)
flutter test test/path/to/related_test.dart
```

Zero tolerance on analyzer issues — info, warning, and error level. If the analyzer complains, fix it.

Do NOT run `flutter analyze` or `flutter test` against the entire project. Target only the files you changed.

---

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include a clear description of what changed and why
- Reference any related issues
- Ensure all checks above pass before requesting review
- Do not include unrelated formatting changes or refactors

---

## What Not to Do

- Do not run `flutter run`, `git commit`, `git push`, or the full test suite in automation
- Do not fork or fragment the Meshtastic firmware protocol
- Do not add airtime increases without measurement, rate limiting, and a feature flag
- Do not leave uncanceled `StreamSubscription` objects

---

## License

By contributing, you agree that your contributions will be licensed under the **GPL-3.0-or-later** license.

All contributions must be compatible with GPL-3.0. Do not include code from incompatible licenses (proprietary, GPL-incompatible open source, etc.).

---

## Questions

Open an issue for questions or discussion before starting large changes. We would rather help you scope the work upfront than reject a PR after you have put in the effort.
