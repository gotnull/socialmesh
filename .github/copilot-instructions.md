# Socialmesh - AI Coding Agent Instructions

## Project Overview
Socialmesh is a Flutter Meshtastic companion app (iOS/Android) for mesh radio communication via BLE and USB. Works fully offline - Firebase is optional for cloud sync, widget marketplace, and profile sharing.

## Architecture

### Key Layers & Data Flow
```
BleTransport/UsbTransport (raw bytes)
    ↓
PacketFramer (USB only - applies 0x94/0xC3 framing)
    ↓
ProtocolService (5200+ lines - parses protobufs, manages config streams)
    ↓
Stream Controllers → Riverpod Providers (MessagesNotifier, NodesNotifier, etc.)
    ↓
UI (ref.watch for reactive rebuilds)
```

**Critical**: `requiresFraming` property on `DeviceTransport` - BLE sends raw protobufs, USB/Serial needs packet framing

### Core Files
- `lib/core/transport.dart` - Abstract transport interface (`DeviceTransport`)
- `lib/services/protocol/protocol_service.dart` - Meshtastic protocol implementation
- `lib/providers/app_providers.dart` - Central Riverpod state (3387 lines)
- `lib/features/` - Feature modules (32+ features: messaging, nodes, map, automations, device, settings, signals, social, etc.)

### Generated Protobufs
```bash
./scripts/generate_protos.sh          # Regenerate from existing protos
./scripts/generate_protos.sh update   # Update from upstream meshtastic/protobufs
```
Output: `lib/generated/meshtastic/*.pb.dart` - excluded from analysis in `analysis_options.yaml`

## Riverpod 3.x Patterns (CRITICAL)

**NEVER use Riverpod 2.x APIs**: ❌ `StateNotifier`, `StateNotifierProvider`, `StateProvider`, `ChangeNotifierProvider`

### Correct Patterns
```dart
// Synchronous state
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() => MyState.initial();
  void update() => state = state.copyWith(x: y);
}
final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);

// Async state
class MyAsyncNotifier extends AsyncNotifier<MyData> {
  @override
  Future<MyData> build() async => await fetchData();
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}
final myAsyncProvider = AsyncNotifierProvider<MyAsyncNotifier, MyData>(MyAsyncNotifier.new);

// Family providers - use Map state, NOT FamilyNotifier
class AdjustmentsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};
  void increment(String key) => state = {...state, key: (state[key] ?? 0) + 1};
}

// Or simple derived family
final itemProvider = Provider.family<Item?, String>((ref, id) {
  return ref.watch(itemsProvider).firstWhereOrNull((i) => i.id == id);
});
```

**Usage**: `ref.watch()` in build methods, `ref.read()` in callbacks, `ref.listen()` for side effects

## Config Screen Pattern (Device Settings)
All device config screens in `lib/features/device/` MUST follow this pattern:
```dart
class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  bool _isLoading = true;
  StreamSubscription<ConfigType>? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    // 1. Apply cached config immediately (fast UI)
    // 2. Subscribe to config stream
    // 3. Request fresh config from device
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _configSubscription?.cancel(); // REQUIRED
    super.dispose();
  }
}
```
Verified by `test/codebase_audit_test.dart`

## Automation System
`AutomationEngine` (`lib/features/automations/automation_engine.dart`) with hysteresis logic:
- **Triggers**: `nodeOnline`, `nodeOffline`, `batteryLow` (hysteresis prevents duplicate alerts), `messageReceived`, `geofenceEnter/Exit`, `silentNode`
- **Actions**: `sendMessage`, `playSound`, `showNotification`, `triggerIfttt`, `openUrl`
- **Example**: Battery low only fires on threshold *crossing* (e.g., 30%→20%), resets when >25%

## Firebase (Optional - Graceful Degradation)
`main.dart` initializes Firebase in background with timeout - app is fully functional offline.

### Firestore Collections
- `users/{uid}`, `profiles/{uid}` - User data (split: private/public)
- `widgets/{id}` - Widget marketplace
- `shopProducts/{id}` - Device catalog
- `shared_nodes/{id}` - QR share links

Deploy functions: `cd functions && firebase deploy --only functions`

## Code Quality (Zero Tolerance)

### Mandatory Checks
```bash
flutter analyze                              # Must have ZERO issues
flutter test test/codebase_audit_test.dart   # All audits must pass
```

### Banned Practices
- ❌ `TODO`, `FIXME`, `HACK` comments
- ❌ `// ignore:` or `// noinspection` (except in generated files)
- ❌ Unimplemented stubs or empty methods
- ❌ Uncanceled `StreamSubscription` or undisposed `TextEditingController`
- ❌ Failing tests (never leave broken tests)

**Critical**: If you cannot fully implement a feature, DO NOT ADD IT. Every button/action must work completely.

## Logging
`lib/core/logging.dart` - category-based logging controlled by `.env`:
```dart
AppLogging.ble('BLE connected');           // BLE_LOGGING_ENABLED
AppLogging.protocol('Parsed packet');      // PROTOCOL_LOGGING_ENABLED
AppLogging.automations('Triggered rule');  // AUTOMATIONS_LOGGING_ENABLED
```

## Code Reuse (Search Before Creating)
- `lib/core/widgets/` - 40+ shared widgets (`NodeAvatar`, `AppBottomSheet`, `InfoTable`, `AnimatedGradientBackground`)
- `lib/utils/` - Utilities (encoding, permissions, snackbar, validation, text_sanitizer)
- Feature `widgets/` subdirectories - check for existing components

## UI Conventions
- **Spacing**: 8dp grid, button padding 16v×24h
- **Buttons**: Filled (primary), Outlined (secondary) - primary actions on right in dialogs
- **Theme**: `lib/core/theme.dart` - use `AccentColors.cyan/purple/pink` for accents, `SemanticColors` for meanings
- **Style**: Sci-fi aesthetic with glowing effects, animations

## Mesh Observer Backend
`mesh-observer/` - Node.js/TypeScript service consuming Meshtastic MQTT:

```bash
cd mesh-observer
npm run build    # Compile TypeScript
railway up       # Deploy to Railway (persistent SQLite at /app/data)
```

**API**: `/api/nodes` (valid nodes), `/api/node/:nodeNum`, `/api/stats`, `/map` (world map UI)  
**Key**: `src/mqtt-observer.ts` has per-node rate limiting (300 msgs/min)

## Database Migrations
**Not implemented** - app hasn't launched. Always reset DB schema in `_createTables()`. No SQLite migrations.

## Development Restrictions
- ❌ Never run `flutter run` (app execution forbidden)
- ❌ Never commit or push to git
- ✅ Always verify with `flutter analyze` and `flutter test`
