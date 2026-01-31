# Releasing Socialmesh

This document describes how to cut a release for the open-source Socialmesh client.

## Prerequisites

- Write access to the repository
- Flutter SDK installed and matching CI version
- All CI checks passing on `main`

## Release Checklist

### 1. Bump Version

Update `pubspec.yaml`:

```yaml
version: X.Y.Z+BUILD
```

- **X.Y.Z** — Semantic version (major.minor.patch)
- **BUILD** — Increment for each release

### 2. Update Changelog

Edit `CHANGELOG.md`:

- Add a new `## [X.Y.Z] - YYYY-MM-DD` section
- Move items from Unreleased (if any) to the new version
- Use headings: Added, Changed, Fixed, Removed

### 3. Verify Locally

```bash
# Format and analyze
dart format .
flutter analyze

# Run tests
flutter test

# Verify version consistency
./tool/check_version.sh
```

### 4. Commit and Tag

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: release vX.Y.Z"
git tag vX.Y.Z
git push origin main --tags
```

### 5. Create GitHub Release

1. Go to **Releases** → **Draft a new release**
2. Select the tag `vX.Y.Z`
3. Title: `vX.Y.Z`
4. Copy the changelog section for this version into the release notes
5. Publish

## What NOT to Include

- Backend service code or configurations
- API keys, secrets, or credentials
- App Store / Play Store publishing steps
- Proprietary cloud function code

The open-source release covers the mobile client only. Backend services remain proprietary.

## Version Format

| Component | Example | Purpose                            |
| --------- | ------- | ---------------------------------- |
| Major     | 1.x.x   | Breaking changes                   |
| Minor     | x.2.x   | New features, backward compatible  |
| Patch     | x.x.0   | Bug fixes, backward compatible     |
| Build     | +96     | Sequential build number for stores |
