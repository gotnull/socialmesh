// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Recent-nodes tab. Lists the latest 5 nodes from the snapshot's
// NodeDex-backed preview. If `capabilities.canShowNodes` is false or
// the list is empty, falls back to UnavailableView.

import SwiftUI

struct NodesView: View {
  @EnvironmentObject private var store: WatchSnapshotStore

  var body: some View {
    NavigationStack {
      Group {
        if let snap = store.latestSnapshot,
           snap.capabilities.canShowNodes,
           !snap.nodes.isEmpty {
          List(snap.nodes) { node in
            _NodeRow(node: node)
          }
          .listStyle(.carousel)
          .opacity(store.isStale ? 0.6 : 1.0)
        } else {
          UnavailableView(
            icon: "dot.radiowaves.left.and.right",
            title: "No recent nodes",
            detail: store.latestSnapshot == nil ? "Waiting for phone" : nil
          )
        }
      }
      .navigationTitle("Nodes")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

private struct _NodeRow: View {
  let node: WatchNodePreview

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(node.shortName ?? node.nodeId)
          .font(.caption.bold())
          .lineLimit(1)
        if let rssi = node.rssi {
          Spacer(minLength: 4)
          Text("\(rssi) dB")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      if let longName = node.longName {
        Text(longName)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Text(_timeLabel(for: node.lastHeardMs))
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 2)
  }

  private func _timeLabel(for ms: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60 { return "now" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    if seconds < 86400 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86400)d ago"
  }
}
