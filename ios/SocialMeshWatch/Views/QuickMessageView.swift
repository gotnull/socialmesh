// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// QuickMessage tab. Lists the six canned-message rows from the
// snapshot, lets the user choose a channel via ChannelPickerView,
// then sends a quickMessage intent via the connectivity manager.
//
// Send is disabled when ANY of the following is true:
//   - capabilities.canQuickReply == false
//   - snapshot is stale
//   - snapshot.channels is empty
//
// On result, surfaces an inline banner with the diagnostic reason for
// rejections. No freeform text input ever.

import SwiftUI

struct QuickMessageView: View {
  @EnvironmentObject private var store: WatchSnapshotStore
  @EnvironmentObject private var connectivity: WatchConnectivityManager
  @Environment(\.dismiss) private var dismiss

  /// When non-nil, this view is a reply composer for a specific received
  /// inbox message: it shows a quote header, defaults the channel to the
  /// message's channel, and sends a `quickReply` intent carrying the
  /// message id. Nil = the standalone Send tab.
  var replyTarget: WatchInboxMessage?

  /// Picked channel for the next send. Nil = "use the snapshot's
  /// default". Updated whenever the user opens ChannelPickerView and
  /// taps a row.
  @State private var pickedChannel: Int?
  @State private var sending: Bool = false
  @State private var lastResult: WatchIntentResult?

  var body: some View {
    NavigationStack {
      Group {
        if let snap = store.latestSnapshot,
           snap.capabilities.canQuickReply {
          _content(snap: snap)
        } else {
          UnavailableView(
            icon: "paperplane.slash",
            title: "Send unavailable",
            detail: _unavailableDetail()
          )
        }
      }
      .navigationTitle(replyTarget == nil ? "Send" : "Reply")
      .navigationBarTitleDisplayMode(.inline)
      // In reply mode, default the channel to the replied-to message's
      // channel so the reply lands in the same conversation.
      .onAppear {
        if let ch = replyTarget?.channelIndex, pickedChannel == nil {
          pickedChannel = ch
        }
      }
      // Clear any per-session channel pick when the phone-side
      // default changes (user updated Settings -> Watch -> Default
      // channel). Without this, _effectiveChannel keeps preferring
      // the stale pickedChannel forever — the new phone setting
      // would only take effect on a fresh app launch, which is
      // exactly the "Channel 1 isn't applying" symptom the developer
      // hit. Phone-side intent wins over the per-session pick.
      .onChange(
        of: store.latestSnapshot?.channels.first(where: { $0.isDefault })?.index
      ) { _, _ in
        pickedChannel = nil
      }
    }
  }

  // MARK: - Body builders

  @ViewBuilder
  private func _content(snap: WatchSnapshot) -> some View {
    let effectiveChannel = _effectiveChannel(snap: snap)
    let canSend = !sending
      && !store.isStale
      && effectiveChannel != nil

    List {
      if let target = replyTarget {
        Section("Replying to \(target.sender)") {
          Text(target.snippet)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          if target.packetId == nil {
            // No Meshtastic packet id (MeshCore row, or aged out) — the send
            // still goes out, just not threaded under the original.
            Label("Sends as a new message", systemImage: "info.circle")
              .font(.caption2)
              .foregroundStyle(.orange)
          }
        }
      }

      if store.isStale, let ago = store.lastReceivedDescription {
        Section {
          Label("Snapshot stale (\(ago))", systemImage: "clock")
            .font(.caption2)
            .foregroundStyle(.orange)
        }
      }

      if !snap.channels.isEmpty {
        Section("Channel") {
          NavigationLink {
            ChannelPickerView(
              channels: snap.channels,
              initialSelection: effectiveChannel ?? snap.channels.first?.index ?? 0,
              onPick: { picked in
                pickedChannel = picked
              }
            )
          } label: {
            HStack {
              Image(systemName: "tag")
                .foregroundStyle(.secondary)
              Text(_channelLabel(snap: snap, channelIndex: effectiveChannel))
                .font(.body)
            }
          }
        }
      }

      Section("Canned messages") {
        ForEach(snap.cannedMessages) { canned in
          Button {
            Task {
              await _send(
                cannedKey: canned.key,
                channelIndex: effectiveChannel ?? -1)
            }
          } label: {
            HStack {
              Text(canned.label)
                .font(.body)
                .multilineTextAlignment(.leading)
              Spacer()
              if sending {
                ProgressView()
              } else {
                Image(systemName: "paperplane")
                  .foregroundStyle(canSend ? .blue : .gray)
              }
            }
          }
          .disabled(!canSend)
          .buttonStyle(.plain)
        }
      }

      if let result = lastResult {
        Section {
          _resultBanner(result: result)
        }
      }
    }
    .listStyle(.carousel)
    .opacity(store.isStale ? 0.7 : 1.0)
  }

  // MARK: - State helpers

  /// Channel index that will be sent: the user's pick if any, else
  /// the snapshot's `isDefault` channel, else the first channel.
  /// Returns nil if there are no channels at all.
  private func _effectiveChannel(snap: WatchSnapshot) -> Int? {
    if let picked = pickedChannel,
       snap.channels.contains(where: { $0.index == picked }) {
      return picked
    }
    if let defaultCh = snap.channels.first(where: { $0.isDefault }) {
      return defaultCh.index
    }
    return snap.channels.first?.index
  }

  private func _channelLabel(snap: WatchSnapshot, channelIndex: Int?) -> String {
    guard let idx = channelIndex,
          let ch = snap.channels.first(where: { $0.index == idx }) else {
      return "—"
    }
    return ch.name
  }

  private func _unavailableDetail() -> String? {
    guard let snap = store.latestSnapshot else {
      return "Waiting for phone"
    }
    if !snap.capabilities.canQuickReply {
      return _reasonFromStatus(snap.connection.status)
    }
    return nil
  }

  private func _reasonFromStatus(_ s: WatchConnectionStatus) -> String {
    switch s {
    case .ready:        return "Ready"
    case .connecting:   return "Connecting…"
    case .degraded:     return "Link degraded"
    case .disconnected: return "Phone is offline"
    case .unsupported:  return "Not supported on this device"
    }
  }

  // MARK: - Send

  private func _send(cannedKey: String, channelIndex: Int) async {
    sending = true
    defer { sending = false }
    let intent: WatchIntent
    if let target = replyTarget {
      intent = WatchIntent.quickReply(
        cannedKey: cannedKey,
        channelIndex: channelIndex,
        replyToMessageId: target.id)
    } else {
      intent = WatchIntent.quickMessage(
        cannedKey: cannedKey, channelIndex: channelIndex)
    }
    let result = await connectivity.send(intent)
    lastResult = result
    // In the reply sheet, a successful send closes the sheet and clears the
    // selected target. Rejections stay so the banner is visible.
    if result.accepted, replyTarget != nil {
      store.clearReplyTarget()
      dismiss()
    }
  }

  @ViewBuilder
  private func _resultBanner(result: WatchIntentResult) -> some View {
    if result.accepted {
      Label("Sent", systemImage: "checkmark.circle.fill")
        .font(.caption)
        .foregroundStyle(.green)
    } else {
      VStack(alignment: .leading, spacing: 2) {
        Label("Not sent", systemImage: "xmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.red)
        if let reason = result.userVisibleReason ?? result.diagnosticReason {
          Text(reason)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }
      }
    }
  }
}
