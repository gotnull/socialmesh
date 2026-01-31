# Contributing to Socialmesh

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run `flutter analyze` — must pass with zero issues
5. Run `flutter test` — all tests must pass
6. Commit with clear, descriptive messages
7. Push to your fork and open a Pull Request

## Code Style

- Follow existing code patterns and conventions
- Use Riverpod 3.x APIs (`Notifier`, `AsyncNotifier`) — not legacy `StateNotifier`
- Add SPDX header to new Dart files: `// SPDX-License-Identifier: GPL-3.0-or-later`
- No `TODO`, `FIXME`, or `HACK` comments
- No `// ignore:` directives except in generated files
- Cancel all `StreamSubscription` objects in `dispose()`

## Pull Request Guidelines

- Keep PRs focused on a single change
- Include a clear description of what and why
- Reference any related issues
- Ensure CI passes before requesting review

## License

By contributing, you agree that your contributions will be licensed under the GPL-3.0-or-later license.

All contributions must be compatible with GPL-3.0. Do not include code from incompatible licenses (e.g., proprietary, GPL-incompatible open source).

## Questions

Open an issue for questions or discussion before starting large changes.
