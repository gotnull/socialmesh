# Backend Services

This document clarifies the boundary between the open-source mobile app and proprietary backend services.

## Repository Scope

This repository contains the **mobile client only**. Backend services, cloud functions, and server infrastructure are proprietary and maintained separately.

## Feature Classification

### Works Without Backend

These features are fully functional with only a Meshtastic radio:

- BLE and USB device connection
- Channel and direct messaging
- Node discovery and network topology
- Device configuration (LoRa, position, Bluetooth, etc.)
- Local message and node storage
- Waypoints and location sharing
- Traceroute and signal history
- Canned messages and quick responses
- QR code channel import/export
- Emergency SOS broadcast
- RTTTL ringtone preview and device upload

### Requires Backend Services

These features require proprietary backend services not included in this repository:

- **Authentication** — Sign-in with Apple/Google
- **Profile Sync** — Cloud backup of user profiles
- **Push Notifications** — Remote alerts when app is backgrounded
- **Shared Links** — `socialmesh://` deep links that resolve via Firestore
- **Social Features** — Following, comments, reactions on Signals
- **Content Moderation** — Automated and manual content review
- **Widget Marketplace** — Cloud-hosted widget templates
- **World Mesh Map** — Global node visualization from MQTT aggregator
- **Premium Entitlements** — Purchase verification via RevenueCat webhooks

### Graceful Degradation

When backend services are unavailable:

- Authentication options are hidden
- Cloud sync silently falls back to local-only
- Push notifications are disabled
- Social features show offline state
- App remains fully functional for core mesh communication

## Contribution Policy

Pull requests that attempt to:

- Reimplement backend services within the client
- Bypass authentication or entitlement checks
- Reverse-engineer or mock proprietary APIs
- Add alternative backend integrations

will not be accepted.

Contributions to improve offline functionality, mesh protocol support, and local features are welcome.

## Questions

For questions about backend services or commercial licensing, contact the maintainers directly.
