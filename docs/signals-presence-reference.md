# Socialmesh Signals / Presence Feature - Complete Reference

## Overview

Signals are Socialmesh's mesh-first, ephemeral content system. Think of them as time-limited "presence broadcasts" - short messages that propagate across the mesh network and automatically expire. Unlike traditional social posts, Signals are designed for real-time, proximity-aware communication without the complexity of follower graphs, likes, or feed algorithms.

**Core Philosophy:**

- Mesh-First: Signals transmit over Meshtastic mesh radio BEFORE any cloud sync
- Ephemeral: All signals have a TTL (Time-To-Live) and auto-expire
- Local-First: Stored in SQLite immediately; Firebase is optional
- Proximity-Aware: Sorted by mesh hop count (closer signals rank higher)
- No Social Metrics: No likes, no follower-only visibility - just presence

---

## Data Model

### Post Model (`lib/models/social.dart`)

Signals use the `Post` model with `postMode: PostMode.signal`:

```dart
class Post {
  final String id;                    // UUID (deterministic for mesh matching)
  final String authorId;              // Firebase UID or "mesh_{nodeIdHex}"
  final String content;               // Max 280 characters
  final List<String> mediaUrls;       // Cloud image URLs (after upload)
  final PostLocation? location;       // Optional GPS (coarsened for privacy)
  final DateTime createdAt;
  final int commentCount;             // Cloud Function maintained

  // Signal-specific fields:
  final PostMode postMode;            // signal or social
  final SignalOrigin origin;          // mesh or cloud
  final DateTime? expiresAt;          // When signal expires
  final int? meshNodeId;              // Source node ID (int)
  final int? hopCount;                // 0=local, 1+=hops away, null=unknown (LOCAL ONLY)
  final ImageState imageState;        // none, local, or cloud
  final List<String> imageLocalPaths; // Before cloud upload (1-4 images)
  final bool hasPendingCloudImage;    // Waiting for cloud image
}
```

### SignalResponse (Comments)

Comments on signals stored at `posts/{signalId}/comments/{commentId}`:

```dart
class SignalResponse {
  final String id;
  final String signalId;
  final String content;
  final String authorId;
  final String? authorName;
  final String? parentId;             // For threaded replies
  final int depth;                    // 0=top-level
  final DateTime createdAt;
  final DateTime expiresAt;           // Inherits from signal
  final int score;                    // upvotes - downvotes
  final int upvoteCount;
  final int downvoteCount;
  final int replyCount;
  final int myVote;                   // +1, -1, or 0 (client-side)
  final bool isDeleted;               // Soft delete
}
```

---

## TTL System

### TTL Options (`SignalTTL` class)

- 15 minutes
- 30 minutes
- 1 hour (default)
- 6 hours
- 24 hours

### Expiry Behavior

- Signals auto-cleanup from local DB when expired
- UI shows countdown with urgency colors (orange <5min, red <1min)
- Pulsing text animation when expiring soon
- Fade-out animation (3 seconds) before removal from feed

---

## Mesh Protocol

### MeshSignalPacket

Transmitted over Meshtastic PRIVATE_APP portnum (256) as JSON:

```dart
class MeshSignalPacket {
  final int senderNodeId;
  final int packetId;
  final String? signalId;    // UUID for cloud matching
  final String content;
  final int ttlMinutes;
  final double? latitude;    // Compressed key: "la"
  final double? longitude;   // Compressed key: "ln"
  final int? hopCount;
  final bool hasImage;       // Compressed key: "i"
}
```

**JSON Keys (Compressed):**

- `id`: Signal UUID
- `c`: Content
- `t`: TTL in minutes
- `la`/`ln`: Lat/lng coordinates
- `i`: Has image flag

**Max Payload:** 200 bytes (UTF-8 encoded)

---

## Image System

### Image Unlock Rules

Images require either:

1. **Auth unlock**: User is authenticated, OR
2. **Proximity unlock**: Sender node seen within last 15 minutes at ≤2 hops

```dart
class ImageUnlockRules {
  static const int proximityThresholdMinutes = 5;
  static const int proximityWindowMinutes = 15;
  static const int maxHopsForProximity = 2;
}
```

### Image States

- `none`: No image
- `local`: Stored locally, not uploaded
- `cloud`: Uploaded to Firebase Storage

### Upload Flow

1. Images copied to persistent storage on creation
2. Mesh packet sent immediately (includes `hasImage` flag)
3. Cloud upload happens async if authenticated
4. Firestore doc updated with `mediaUrls`
5. Receivers download via post listener

---

## Storage Architecture

### Local (SQLite - `signals.db`)

Tables:

- `signals`: Main signal storage with all Post fields
- `node_proximity`: Tracks when nodes were seen (for image unlock)
- `comments`: Local cache of cloud comments

Indexes on `expiresAt`, `meshNodeId`

### Cloud (Firebase)

**Firestore:**

- `posts/{signalId}`: Signal document
- `posts/{signalId}/comments/{commentId}`: Comments
- `posts/{signalId}/comments/{commentId}/votes/{uid}`: User votes
- `users/{uid}/saved_signals/{signalId}`: Bookmarks

**Storage:**

- `signals/{userId}/{signalId}_0.jpg` (etc.): Signal images

---

## Service Layer

### SignalService (`lib/services/signal_service.dart`)

3260+ lines handling:

- SQLite persistence
- Firestore sync
- Image upload/download
- Comments (CRUD + voting)
- Proximity tracking
- Duplicate detection
- Real-time listeners

Key Methods:

```dart
Future<Post> createSignal({...})           // Create new signal
Future<Post?> createSignalFromMesh({...})  // Process received mesh signal
Future<List<Post>> getActiveSignals()      // Non-expired signals
Future<void> deleteSignal(String id)       // Delete with cloud sync
bool isImageUnlocked(Post signal)          // Check unlock status
```

### ProtocolService Integration

```dart
// Sending
Future<int> sendSignal({
  required String signalId,
  required String content,
  required int ttlMinutes,
  double? latitude,
  double? longitude,
  bool hasImage,
})

// Receiving
Stream<MeshSignalPacket> get signalStream
```

---

## Provider Layer (`lib/providers/signal_providers.dart`)

### SignalFeedState

```dart
class SignalFeedState {
  final Map<String, Post> _signalMap;      // Single source of truth
  final Set<String> fadingSignalIds;        // Expiring animations
  final Set<String> newlyAddedSignalIds;    // Entrance animations
  final bool isLoading;
  final String? error;
  final DateTime? lastRefresh;
}
```

### SignalFeedNotifier

Features:

- Periodic cleanup (every minute)
- Auto-refresh (every 30 seconds)
- Global countdown timer (every second)
- App lifecycle handling (cleanup on resume)
- Mesh integration wiring
- Remote deletion handling

### Key Providers

```dart
signalFeedProvider           // Main feed state
signalServiceProvider        // Service singleton
activeSignalCountProvider    // Count of active signals
signalsFromNodeProvider      // Signals from specific node
mySignalsProvider            // Current user's signals
isSignalFadingProvider       // Expiry animation state
isSignalNewlyAddedProvider   // Entrance animation state
signalBookmarksProvider      // Saved signals (Firestore)
signalViewModeProvider       // list/grid/gallery/map
hiddenSignalsProvider        // Manually hidden signals
```

---

## UI Components

### Screens

**PresenceFeedScreen** (`lib/features/signals/screens/presence_feed_screen.dart`)

- Main signal feed with filtering/sorting
- View modes: List, Grid, Gallery, Map
- Search across content, author, node ID
- Filters: All, Saved, Nearby, Mesh-only, With media, With location, With comments, Expiring soon, Hidden

**CreateSignalScreen** (`lib/features/signals/screens/create_signal_screen.dart`)

- 280 char limit with counter
- TTL selector chips
- Optional location (coarsened)
- Image picker (1-4 images)
- Content moderation pre-check

**SignalDetailScreen** (`lib/features/signals/screens/signal_detail_screen.dart`)

- Full signal view
- Threaded comments with voting
- Reply functionality
- Delete/report actions

### Widgets

- `SignalCard`: Main signal display with header, content, images, location, TTL footer
- `SignalGridCard`: Compact grid view
- `SignalGalleryView`: Full-screen image gallery
- `SignalMapView`: Map with signal markers
- `SignalTTLFooter`: Live countdown with urgency animation
- `TTLSelector`: Creation TTL picker
- `ProximityIndicator`: Animated dots showing hop count (1-3 dots)
- `SwipeableSignalItem`: Swipe actions (save, hide, delete)
- `SignalSkeleton`: Loading placeholder
- `ActiveSignalsBanner`: Sticky header with author avatars

---

## Sorting & Filtering

### Default Sort Order

1. Own device signals first (`meshNodeId == myNodeNum`)
2. Hop count ascending (closer first, null = lowest priority)
3. Expiry time ascending (expiring soon first)
4. Creation time descending (newest first)

### Filter Options

```dart
enum SignalFilter {
  all,
  saved,          // Bookmarked
  nearby,         // hopCount 0-1
  meshOnly,       // authorId starts with "mesh_"
  withMedia,      // Has images
  withLocation,   // Has GPS
  withComments,   // commentCount > 0
  expiringSoon,   // < 5 minutes remaining
  hidden,         // Manually hidden
}

enum SignalSortOrder {
  proximity,      // Hop count
  expiring,       // TTL remaining
  newest,         // Creation time
}
```

---

## Privacy Features

### Location Coarsening

Signals use randomized location within a configurable radius:

```dart
PostLocation.coarseFromCoordinates(
  latitude: exactLat,
  longitude: exactLng,
  radiusMeters: settings.signalLocationRadiusMeters, // Default 500m
)
```

### Signal Settings (`SignalSettingsScreen`)

- Location radius: 100m, 250m, 500m, 1km, 5km
- Max images per signal: 1-4
- Notification preferences (signals, votes)

---

## Cloud Functions Integration

### Comment Voting

Votes are processed by Cloud Functions to maintain atomic counters:

- `posts/{signalId}/comments/{commentId}/votes/{uid}`: Vote document
- Cloud Function updates `score`, `upvoteCount`, `downvoteCount` on parent comment

### Content Moderation

Images uploaded to `signal_images_temp/` trigger moderation check before being moved to final location.

---

## Duplicate Detection

### Mesh Level

- `MeshPacketDedupeStore`: Tracks `(packetType, senderNodeId, packetId)` tuples
- TTL: 30 minutes

### Signal Level

- Dedupe by `signalId` in SQLite signals table
- Prevents processing same signal twice from different routes

---

## Connectivity Modes

```dart
class SignalConnectivity {
  final bool hasInternet;
  final bool isAuthenticated;
  final bool isBleConnected;

  bool get canUseCloud => hasInternet && isAuthenticated;
  bool get canUseMesh => isBleConnected;
}
```

Signals work in three modes:

1. **Full mode**: Mesh + Cloud (authenticated with internet)
2. **Mesh-only mode**: No cloud sync (offline or debug mode)
3. **Cloud-only mode**: No mesh device connected

---

## Testing

Key test files:

- `test/providers/signal_bookmark_provider_test.dart`
- `test/providers/signal_countdown_test.dart`
- `test/services/protocol/mesh_signal_packet_test.dart`
- `test/services/protocol/protocol_signal_flow_test.dart`

---

## File Locations

```
lib/
├── features/signals/
│   ├── signals.dart                 # Module exports
│   ├── screens/
│   │   ├── presence_feed_screen.dart
│   │   ├── create_signal_screen.dart
│   │   └── signal_detail_screen.dart
│   ├── widgets/
│   │   ├── signal_card.dart
│   │   ├── signal_grid_card.dart
│   │   ├── signal_gallery_view.dart
│   │   ├── signal_map_view.dart
│   │   ├── signal_ttl_footer.dart
│   │   ├── signal_composer.dart
│   │   ├── signal_thumbnail.dart
│   │   ├── signal_skeleton.dart
│   │   ├── signals_empty_state.dart
│   │   ├── proximity_indicator.dart
│   │   ├── ttl_selector.dart
│   │   ├── live_pulse_indicator.dart
│   │   ├── active_signals_banner.dart
│   │   ├── swipeable_signal_item.dart
│   │   ├── snappable_signal_wrapper.dart
│   │   └── double_tap_heart.dart
│   └── utils/
│       └── signal_utils.dart
├── providers/
│   ├── signal_providers.dart
│   └── signal_bookmark_provider.dart
├── services/
│   └── signal_service.dart
├── models/
│   └── social.dart (Post model)
└── features/settings/
    └── signal_settings_screen.dart
```

---

## Key Architectural Decisions

1. **Deterministic Signal IDs**: UUID generated on creation, included in mesh packet for cloud document matching
2. **Local-First Storage**: SQLite write happens before any cloud operation
3. **Deferred Image Upload**: Images stored locally first, uploaded async when authenticated
4. **Proximity-Based Unlocking**: Privacy feature - strangers can't see your images unless nearby
5. **Real-Time Listeners**: Firestore listeners for comments/votes/post updates
6. **Graceful Degradation**: Full functionality offline, cloud sync when available
7. **Automatic Cleanup**: Timers handle expiry, duplicate detection prevents bloat
