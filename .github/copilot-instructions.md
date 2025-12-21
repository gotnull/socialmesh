# copilot-instructions.md

## Project Overview
Socialmesh is a Flutter Meshtastic companion app (iOS/Android) for mesh radio communication via BLE and USB. It works fully offline - Firebase is optional for cloud sync.

## Architecture

### Key Layers
- **Transport** (`lib/core/transport.dart`): Abstract `DeviceTransport` interface for BLE/USB with `requiresFraming` property (USB needs framing, BLE doesn't)
- **Protocol** (`lib/services/protocol/protocol_service.dart`): 4000+ line service handling Meshtastic protobufs, config streams, message delivery tracking
- **Providers** (`lib/providers/app_providers.dart`): Central Riverpod providers (~2000 lines) - `MessagesNotifier`, `NodesNotifier`, `ChannelsNotifier`, connection state
- **Features** (`lib/features/`): Feature modules (messaging, nodes, map, automations, settings, device config screens)

### Data Flow
1. `BleTransport`/`UsbTransport` → raw bytes
2. `PacketFramer` (USB only) → `ProtocolService` → parsed protobufs
3. Stream controllers broadcast to Riverpod providers
4. UI watches providers via `ref.watch()`

### Generated Code
Protobufs in `lib/generated/` - regenerate with `./scripts/generate_protos.sh` after changing `protos/meshtastic/*.proto`

## Riverpod 3.x Patterns (CRITICAL)
```dart
// ✅ Correct: Notifier with build()
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() => MyState.initial();
  void update(MyState s) => state = s;
}
final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);

// ❌ Wrong: StateNotifier (Riverpod 2.x)
class MyNotifier extends StateNotifier<MyState> { ... }  // NEVER
```
- Use `AsyncNotifier`/`AsyncNotifierProvider` for async loading
- Access in widgets: `ref.watch()` for reactive, `ref.read()` for one-time

## Code Quality Rules
- Zero `flutter analyze` issues (info, warning, error)
- Use `debugPrint()` not `print()`
- NEVER use `// ignore:` or `// noinspection`
- Cancel all `StreamSubscription` in `dispose()`
- Dispose all `TextEditingController`s
- Config screens: implement `_loadCurrentConfig()` with `_isLoading` state

## Code Reuse
Search before implementing:
- `lib/core/widgets/` - shared widgets (`NodeAvatar`, `InfoTable`, `AppBottomSheet`)
- `lib/utils/` - utilities (encoding, permissions, snackbar, validation)
- Feature `widgets/` folders - check edit screens for reusable widgets

## Logging
Use `AppLogging` from `lib/core/logging.dart`:
```dart
AppLogging.ble('BLE message');
AppLogging.protocol('Protocol message');
AppLogging.automations('Automation message');
```
Controlled via `.env` flags like `BLE_LOGGING_ENABLED=false`

## Testing
Run codebase audits: `flutter test test/codebase_audit_test.dart`
Checks: empty stubs, resource cleanup, config screen patterns

## UI Guidelines
- 8dp spacing grid, button padding: 16v × 24h
- Primary actions: filled buttons (right side in dialogs)
- Theme colors: `lib/core/theme.dart` - use `AccentColors` for app accent
- Visual style: sci-fi aesthetics, glowing effects, animations

## Restrictions
- Never run the Flutter app
- Never commit or push to git
