// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Top-level container for the watchOS app. Uses the page-based
// TabView style (standard on watchOS) so the user swipes horizontally
// between Status / Inbox / Nodes / Send.

import SwiftUI

struct RootView: View {
  var body: some View {
    TabView {
      StatusView()
      InboxView()
      NodesView()
      QuickMessageView()
    }
    .tabViewStyle(.page)
  }
}
