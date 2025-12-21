# copilot-instructions.md

## Communication
- Keep responses concise and focused on the task.
- Avoid referencing internal tools or implementation details.
- Only create additional files when explicitly requested.
- Provide a short confirmation when a task is finished.

## Code Changes
- Apply changes directly to the codebase.
- Create only files that contribute to functional app behavior.
- Do not modify documentation unless requested.

## Code Quality
- Do not leave placeholders or temporary comments.
- Fully implement features or remove incomplete ones.
- Resolve ALL issues from `flutter analyze` including info, warning, and error levels.
- Replace deprecated APIs without suppression flags.
- Code must pass `flutter analyze` with zero issues of any severity.
- Use `debugPrint()` instead of `print()` for debug logging.
- Ensure every feature is fully wired and functional end to end.
- NEVER use `// ignore:` comments to suppress warnings or errors.
- NEVER use `// noinspection` or any other suppression mechanism.
- Fix the root cause of issues rather than hiding them.

## Riverpod (CRITICAL)
- ALWAYS use Riverpod 3.x patterns with `Notifier`, `AsyncNotifier`, `FamilyNotifier`.
- NEVER use old Riverpod 2.x `StateNotifier` or `StateNotifierProvider`.
- Providers must use `build()` method, NOT constructor initialization.
- Use `NotifierProvider<MyNotifier, MyState>` pattern.
- Use `AsyncNotifierProvider` for async state management.
- For family providers, extend `FamilyNotifier` or `FamilyAsyncNotifier`.
- State updates use `state = newState`, NOT `state = state.copyWith()` patterns from StateNotifier.

## Complexity (CRITICAL)
- NEVER opt for simplicity over functionality.
- Implement the FULL solution regardless of complexity.
- Do not simplify, shortcut, or reduce scope - complete the entire task as specified.
- If a feature requires complex logic, implement all of it without compromise.
- Never suggest "simpler alternatives" unless explicitly asked.
- Complexity is acceptable; incomplete functionality is not.

## Code Reuse (CRITICAL)
- BEFORE implementing any new widget, utility, or logic, SEARCH the codebase for existing implementations.
- Look for existing widgets/cards in related screens (e.g., edit screens have widgets that creation screens should reuse).
- Extract and refactor shared functionality into reusable components rather than duplicating code.
- Check `lib/core/widgets/`, `lib/utils/`, and feature-specific files for existing utilities.
- If similar logic exists, refactor to create a shared component instead of reimplementing.
- Proven, tested code is always preferable to new implementations.
- When adding features to wizards/creation flows, first check the corresponding edit/form screens for reusable widgets.

## Systematic Verification (CRITICAL)
- NEVER assume you have found all instances of a pattern. Always search exhaustively.
- When fixing a bug pattern, FIRST run a comprehensive search to find ALL affected files before making any changes.
- Use grep/find commands to discover the full scope BEFORE claiming completeness.
- After making changes, run verification commands to PROVE all instances are fixed.
- When asked "are you sure?" or similar, re-run discovery commands to verify - do not rely on memory.
- For config screens or similar patterns: search for `_loadCurrentConfig`, `_isLoading`, empty stubs, etc. across the ENTIRE codebase.
- Always provide evidence (command output) when claiming completeness, not just assertions.

## UI and UX
- Maintain consistent styling and sizing.
- Avoid duplicating actions across multiple UI elements.
- Prefer shallow navigation and inline actions when appropriate.
- Apply clear hierarchy: primary actions use filled buttons, secondary use outlined or text.
- Provide visible state feedback such as badges or indicators.
- Use an 8dp spacing grid.
- Button padding: 16 vertical, 24 horizontal.
- Dialogs place the primary action on the right with equal button sizes.
- Display existing data and allow inline editing.
- Ensure interactions are polished, intuitive, and responsive.

## Visual Design Philosophy
- ALWAYS choose the most visually impressive and engaging implementation.
- Never default to "simple" when "incredible" is achievable.
- Prioritize sci-fi aesthetics: glowing effects, dynamic animations, futuristic shapes.
- Use custom geometry over basic primitives (diamonds/octahedrons over cubes, etc.).
- Add visual flair: pulsing animations, gradient effects, particle-like details.
- Every visual element should feel premium and cutting-edge.
- If something can glow, animate, or look more futuristic - make it so.

## Restrictions
- Never run the Flutter app.
- Never commit or push to git.
