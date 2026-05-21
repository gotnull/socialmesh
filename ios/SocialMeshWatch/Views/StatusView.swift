// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Status tab. Shows the current link state, active protocol and
// device names, and a stale badge when the snapshot is older than the
// stalenessThreshold. Read-only.

import SwiftUI

struct StatusView: View {
  @EnvironmentObject private var store: WatchSnapshotStore

  var body: some View {
    NavigationStack {
      VStack(spacing: 8) {
        if let snap = store.latestSnapshot {
          // Subtle animation while connecting: SF Symbols'
          // variable-color effect animates the antenna bars in
          // sequence so the user has a clear "something is in
          // progress" cue without us leaking enum names into the
          // UI. Idle / ready / disconnected / degraded keep the
          // static icon (they're settled or attention states, not
          // active-progress states).
          _statusIcon(for: snap.connection.status)
            .font(.largeTitle)
            .foregroundStyle(_statusColor(for: snap.connection.status))
            .symbolEffect(
              .variableColor.iterative.reversing,
              isActive: snap.connection.status == .connecting
            )
            .padding(.top, 4)

          Text(_statusLabel(for: snap.connection.status))
            .font(.headline)

          if let device = snap.connection.activeDeviceName {
            Text(device)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let proto = snap.connection.activeProtocolDisplayName {
            Text(proto)
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }

          if let reason = snap.connection.readinessReason {
            Text(reason)
              .font(.caption2)
              .foregroundStyle(.orange)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }

          if store.isStale, let ago = store.lastReceivedDescription {
            Spacer(minLength: 4)
            Label("Updated \(ago)", systemImage: "exclamationmark.triangle")
              .font(.caption2)
              .foregroundStyle(.orange)
          }
        } else {
          ProgressView()
          Text("Waiting for phone")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal)
      .navigationTitle("Status")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func _statusIcon(for s: WatchConnectionStatus) -> Image {
    switch s {
    case .ready:        return Image(systemName: "checkmark.circle.fill")
    case .connecting:   return Image(systemName: "antenna.radiowaves.left.and.right")
    case .degraded:     return Image(systemName: "exclamationmark.triangle.fill")
    case .disconnected: return Image(systemName: "wifi.slash")
    case .unsupported:  return Image(systemName: "questionmark.circle")
    }
  }

  private func _statusColor(for s: WatchConnectionStatus) -> Color {
    switch s {
    case .ready:        return .green
    case .connecting:   return .yellow
    case .degraded:     return .orange
    case .disconnected: return .gray
    case .unsupported:  return .gray
    }
  }

  private func _statusLabel(for s: WatchConnectionStatus) -> String {
    switch s {
    case .ready:        return "Ready"
    case .connecting:   return "Connecting"
    case .degraded:     return "Degraded"
    case .disconnected: return "Disconnected"
    case .unsupported:  return "Unsupported"
    }
  }
}
