// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Channel picker used by QuickMessageView. Shows the snapshot's
// channel list with the `isDefault` entry pre-highlighted. Tapping a
// channel commits the choice via `onPick` and pops the view.
//
// The Watch never edits the persisted default-channel setting: that
// stays a phone-side setting (Settings -> Apple Watch -> Default
// channel). The Watch's picker only overrides for the in-flight send.

import SwiftUI

struct ChannelPickerView: View {
  let channels: [WatchChannelPreview]
  let initialSelection: Int
  let onPick: (Int) -> Void

  var body: some View {
    List(channels) { channel in
      Button {
        onPick(channel.index)
      } label: {
        HStack {
          Image(systemName: "tag")
            .foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 0) {
            Text(channel.name)
              .font(.body)
              .lineLimit(1)
            Text("Channel \(channel.index)")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer()
          if channel.index == initialSelection {
            Image(systemName: "checkmark")
              .foregroundStyle(.blue)
          }
        }
      }
      .buttonStyle(.plain)
    }
    .listStyle(.carousel)
    .navigationTitle("Channel")
    .navigationBarTitleDisplayMode(.inline)
  }
}
