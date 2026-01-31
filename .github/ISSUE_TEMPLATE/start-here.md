---
name: Start Here
about: New to Socialmesh? Read this before opening an issue
title: ""
labels: ""
assignees: ""
---

## Welcome to Socialmesh

Socialmesh is a Flutter companion app for Meshtastic mesh radios. It connects to Meshtastic devices via Bluetooth Low Energy (BLE) or USB serial and provides messaging, node management, mapping, and device configuration.

### What this repository covers

- The Flutter mobile app (iOS and Android)
- BLE and USB transport layers
- Meshtastic protocol implementation
- Local SQLite storage
- UI components and features

### What is out of scope

This repository does NOT cover:

- Backend services (Firebase, cloud functions, APIs)
- Payment processing or subscription infrastructure
- Server deployment or hosting
- The Meshtastic firmware itself
- The mesh-observer backend service

PRs that attempt to reimplement backend services or add new cloud dependencies will not be accepted.

### Before you open an issue

1. Read [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) to understand how the app is structured
2. Read [docs/BACKEND.md](../docs/BACKEND.md) to understand what requires cloud services
3. Read [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines
4. Search existing issues to avoid duplicates

### Where to go

| I want to...                    | Go here                                                       |
| ------------------------------- | ------------------------------------------------------------- |
| Report a bug                    | Use the **Bug Report** template                               |
| Request a feature               | Use the **Feature Request** template                          |
| Ask a question about the code   | Open a **Discussion** (if enabled) or issue                   |
| Ask about Meshtastic firmware   | [meshtastic/firmware](https://github.com/meshtastic/firmware) |
| Report a security vulnerability | See [SECURITY.md](../SECURITY.md)                             |

### Not sure if your issue belongs here?

If your issue involves:

- Cloud sync, profiles, or widget marketplace: These are optional Firebase features. The app works fully offline without them.
- Meshtastic device behavior: This is firmware-level, not app-level.
- Backend API changes: Out of scope for this repository.

Close this issue and use the appropriate template for bugs or feature requests.
