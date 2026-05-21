// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Apple Watch companion app entry point. Owns the lifetime of the
// snapshot store and the connectivity manager; wires them into the
// SwiftUI environment so every view reads from the same instances.
//
// Activation order (mirrors the iPhone-side bridge in
// `ios/Runner/WatchCompanion/WatchCompanionBridge.swift`):
//   1. App launches, SwiftUI builds the scene.
//   2. `.onAppear` on RootView calls `connectivity.attachStore(store)`
//      then `connectivity.activate()`.
//   3. WCSession activates -> phone's bridge logs reachability flip.
//   4. Phone pushes the latest snapshot via `updateApplicationContext`.
//   5. `didReceiveApplicationContext` decodes into WatchSnapshot and
//      writes to the store; SwiftUI rebuilds.

import SwiftUI

@main
struct SocialMeshWatchApp: App {
  @StateObject private var store = WatchSnapshotStore()
  @StateObject private var connectivity = WatchConnectivityManager()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(store)
        .environmentObject(connectivity)
        .onAppear {
          connectivity.attachStore(store)
          connectivity.activate()
        }
    }
  }
}
