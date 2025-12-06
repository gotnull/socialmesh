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
- Resolve all warnings and errors.
- Replace deprecated APIs without suppression flags.
- Code must pass `flutter analyze` cleanly.
- Ensure every feature is fully wired and functional end to end.

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

## Restrictions
- Never run the Flutter app.
- Never commit or push to git.
