# copilot-instructions.md

## Communication Guidelines
- Keep responses concise and focused on the task.
- Avoid mentioning any internal tools.
- Do not create documentation or summary files unless explicitly requested.
- Provide a brief confirmation after completing tasks.

## Code Changes
- Apply changes directly in the codebase.
- Only create files that contribute to functional app behavior.
- Do not modify README, CHANGELOG, or other documentation unless asked.

## Code Quality Standards
- Never leave placeholders such as TODO, coming soon, or temporary comments.
- Fully implement features or remove incomplete ones.
- Resolve all warnings and errors.
- Replace deprecated APIs immediately without suppression flags.
- Treat all code as if `flutter analyze` must return clean.
- Ensure every feature is fully wired and functional end to end.

## Professional UI and UX Standards
- Use consistent styling and component sizing within the same context.
- Do not duplicate actions across multiple UI elements.
- Keep navigation shallow and allow inline actions where practical.
- Apply strong visual hierarchy: primary actions are filled buttons, secondary actions are outlined or text.
- Provide clear state feedback such as badges or indicators.
- Follow an 8dp spacing grid.
- Match button heights and use padding: 16 vertical, 24 horizontal.
- Dialogs place primary action on the right with equal button sizes.
- Show existing data and support inline editing.
- Use pushReplacement where it reduces unnecessary back navigation.
- Ensure all interactions feel polished, intuitive, and responsive.

## Development Restrictions
- Never run the Flutter app.
- Never commit or push to git.
- User handles all execution and version control.