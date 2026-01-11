# copilot-instructions.md

## Project Overview
Socialmesh is a Flutter Meshtastic companion app (iOS/Android) for mesh radio communication via BLE and USB. Works fully offline - Firebase is optional for cloud sync, widget marketplace, and profile sharing.

## Architecture

### Key Layers
- **Transport** (`lib/core/transport.dart`): Abstract `DeviceTransport` interface for BLE/USB with `requiresFraming` (USB needs framing, BLE doesn't)
- **Protocol** (`lib/services/protocol/protocol_service.dart`): 4000+ line service handling Meshtastic protobufs, config streams, message delivery tracking
- **Providers** (`lib/providers/app_providers.dart`): Central Riverpod providers - `MessagesNotifier`, `NodesNotifier`, `ChannelsNotifier`, connection state
- **Features** (`lib/features/`): Feature modules (messaging, nodes, map, automations, settings, device config screens)

### Data Flow
1. `BleTransport`/`UsbTransport` → raw bytes
2. `PacketFramer` (USB only) → `ProtocolService` → parsed protobufs
3. Stream controllers broadcast to Riverpod providers
4. UI watches providers via `ref.watch()`

### Generated Code
Protobufs in `lib/generated/` - regenerate with `./scripts/generate_protos.sh` after changing `protos/meshtastic/*.proto`

## Firebase (Optional - Offline-First)
Firebase is background-initialized with timeout; app works fully without it. See `main.dart` `_initializeFirebaseInBackground()`.

### Collections (Firestore)
- `users/{uid}` - User profile data (owner read/write)
- `profiles/{uid}` - Public profile info (public read, owner write)
- `widgets/{id}` - Widget marketplace (public read, authenticated create)
- `shopProducts/{id}` - Device shop catalog (public read, admin write)
- `shared_nodes/{id}` - Share links (public read, authenticated create)

### Cloud Functions (`functions/src/index.ts`)
TypeScript functions for widget marketplace API, share link Open Graph, admin operations. Deploy: `firebase deploy --only functions`

### Storage
Profile avatars in `profile_avatars/{uid}.jpg`. Widget assets in respective folders.

## Riverpod 3.x Patterns (CRITICAL)
This project uses **Riverpod 3.x** (riverpod_annotation NOT used). Follow these patterns strictly:

### Basic Notifier (synchronous state)
```dart
class MyNotifier extends Notifier<MyState> {
  @override
  MyState build() => MyState.initial(); // Initial state
  
  void update(MyState s) => state = s;
  void doSomething() {
    final service = ref.read(someServiceProvider);
    state = state.copyWith(loading: true);
  }
}
final myProvider = NotifierProvider<MyNotifier, MyState>(MyNotifier.new);
```

### AsyncNotifier (async loading)
```dart
class MyAsyncNotifier extends AsyncNotifier<MyData> {
  @override
  Future<MyData> build() async {
    return await ref.read(serviceProvider).fetchData();
  }
  
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}
final myAsyncProvider = AsyncNotifierProvider<MyAsyncNotifier, MyData>(MyAsyncNotifier.new);
```

### DEPRECATED - Never use these (Riverpod 2.x):
- ❌ `StateNotifier` / `StateNotifierProvider`
- ❌ `StateProvider` (use `NotifierProvider` instead)
- ❌ `ChangeNotifierProvider`

### Provider types still valid:
- ✅ `Provider` - computed/derived values
- ✅ `FutureProvider` - one-shot async
- ✅ `StreamProvider` - reactive streams
- ✅ `NotifierProvider` - mutable state with methods
- ✅ `AsyncNotifierProvider` - async mutable state
- ✅ `.family` modifier for parameterized providers
- ✅ `.autoDispose` modifier for auto-cleanup

### Family Providers (no FamilyNotifier in Riverpod 3)
```dart
// For family with Notifier, use a global notifier with Map state:
class CountAdjustmentsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};
  
  void increment(String key) {
    state = {...state, key: (state[key] ?? 0) + 1};
  }
}
final adjustmentsProvider = NotifierProvider<CountAdjustmentsNotifier, Map<String, int>>(
  CountAdjustmentsNotifier.new,
);

// Or use simple Provider.family for derived values:
final itemProvider = Provider.family<Item?, String>((ref, id) {
  final items = ref.watch(itemsProvider);
  return items.firstWhereOrNull((i) => i.id == id);
});
```

### Usage patterns:
- `ref.watch()` - reactive rebuilds (use in build methods)
- `ref.read()` - one-time reads (use in callbacks/methods)
- `ref.invalidate(provider)` - force refresh
- `ref.listen()` - side effects on changes

## Config Screen Pattern
All device config screens follow this structure:
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
    // 1. Apply cached config immediately
    // 2. Subscribe to config stream
    // 3. Request fresh config from device
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    super.dispose();
  }
}
```

## Automation System
`AutomationEngine` (`lib/features/automations/`) processes triggers and executes actions:
- **Triggers**: `nodeOnline`, `nodeOffline`, `batteryLow`, `messageReceived`, `geofenceEnter/Exit`, `silentNode`
- **Actions**: `sendMessage`, `playSound`, `showNotification`, `triggerIfttt`, `openUrl`
- **Conditions**: Node filters, time windows, battery thresholds
- Hysteresis logic prevents duplicate alerts (e.g., battery threshold crossing)

## Code Quality Rules
- Zero `flutter analyze` issues (info, warning, error)
- **ALL tests must pass** - never leave failing tests, regardless of when they broke
- Use `debugPrint()` not `print()`
- NEVER use `// ignore:` or `// noinspection`
- Cancel all `StreamSubscription` in `dispose()`
- Dispose all `TextEditingController`s

## No Placeholders or TODOs (CRITICAL)
- **NEVER** leave `TODO`, `FIXME`, `HACK`, or any placeholder comments
- **NEVER** write "coming soon", "not yet implemented", or stub implementations
- **NEVER** add empty method bodies or pass-through functions that do nothing
- **FULLY IMPLEMENT** every feature, method, and callback - no exceptions
- If a feature cannot be fully implemented, **DO NOT ADD IT AT ALL**
- Every button, action, and interaction must have complete, working functionality
- Treat incomplete code as a bug - it should not exist in the codebase

## Code Reuse
Search before implementing:
- `lib/core/widgets/` - shared widgets (`NodeAvatar`, `InfoTable`, `AppBottomSheet`)
- `lib/utils/` - utilities (encoding, permissions, snackbar, validation)
- Feature `widgets/` folders - check edit screens for reusable components

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
Checks: empty stubs, resource cleanup, config screen patterns, subscription disposal

## UI Guidelines
- 8dp spacing grid, button padding: 16v × 24h
- Primary actions: filled buttons (right side in dialogs)
- Theme colors: `lib/core/theme.dart` - use `AccentColors` for app accent
- Visual style: sci-fi aesthetics, glowing effects, animations

## Mesh Observer (Backend)
The `mesh-observer/` directory contains a Node.js/TypeScript service that collects Meshtastic node data via MQTT.

### Deployment
After making changes to mesh-observer:
```bash
cd mesh-observer
npm run build    # Verify TypeScript compiles
railway up       # Deploy to Railway (persistent volume at /app/data)
```

### Key Files
- `src/index.ts` - Express API server, MQTT topics config
- `src/mqtt-observer.ts` - MQTT message handling, per-node rate limiting (300 msgs/min)
- `src/node-store.ts` - In-memory cache + SQLite persistence, validity filtering, TTLs
- `src/database.ts` - SQLite schema and queries

### API Endpoints
- `GET /map` - Interactive world mesh map (web version of app's World Map)
- `GET /api/nodes` - Returns valid nodes (with name + position). Use `?all=true` for raw data
- `GET /api/node/:nodeNum` - Single node details
- `GET /api/stats` - Node counts, decode stats, rate limit info

## Database Migrations
**Not needed** - the app hasn't gone live yet. Always blow away the database on each install. Don't implement SQLite migrations; just update the table schema in `_createTables()` methods.

## Restrictions
- Never run the Flutter app
- Never commit or push to git
