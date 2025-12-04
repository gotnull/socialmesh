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
- Use pushReplacement when it reduces unnecessary back navigation.
- Ensure interactions are polished, intuitive, and responsive.

## Restrictions
- Never run the Flutter app.
- Never commit or push to git.
