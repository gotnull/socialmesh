// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Generic empty / unavailable placeholder. Used by the Inbox, Nodes,
// and QuickMessage tabs when their corresponding capability flag is
// false or there is no data to render. Keeps the watchOS surface
// consistent across the three "this section can't show anything right
// now" cases.

import SwiftUI

struct UnavailableView: View {
  let icon: String
  let title: String
  let detail: String?

  init(icon: String, title: String, detail: String? = nil) {
    self.icon = icon
    self.title = title
    self.detail = detail
  }

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
        .multilineTextAlignment(.center)
      if let detail = detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
