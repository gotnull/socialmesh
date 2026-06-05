//
//  CarPlaySceneDelegate.swift
//  Runner
//
//  CarPlay template scene for the communication surface: a two-tab browse UI
//  (Channels / Direct Messages) built from a Dart conversation snapshot
//  (CarPlayManager "carplayListConversations"). Per CarPlay messaging
//  convention, an unread item omits phoneOrEmailAddress so a tap triggers Siri
//  read-back; a read item sets it so a tap starts a voice compose.
//
//  The phone window scene is handled separately by SceneDelegate
//  (FlutterSceneDelegate); this delegate only owns the CarPlay scene.
//

import CarPlay

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var channelsTemplate: CPListTemplate?
    private var directMessagesTemplate: CPListTemplate?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let channels = CPListTemplate(title: "Channels", sections: [loadingSection()])
        channels.tabImage = UIImage(systemName: "bubble.left.and.bubble.right")
        let dms = CPListTemplate(title: "Direct Messages", sections: [loadingSection()])
        dms.tabImage = UIImage(systemName: "bubble.left.and.text.bubble.right")
        channelsTemplate = channels
        directMessagesTemplate = dms

        let tabBar = CPTabBarTemplate(templates: [channels, dms])
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        refresh()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        channelsTemplate = nil
        directMessagesTemplate = nil
    }

    // Pull a fresh conversation snapshot from Dart and rebuild both tabs.
    private func refresh() {
        CarPlayManager.shared.request("carplayListConversations", [:]) { [weak self] reply in
            guard let self = self else { return }
            let rows = (reply as? [[String: Any]]) ?? []
            let channels = rows.filter { ($0["isChannel"] as? Bool) ?? false }
            let dms = rows.filter { !(($0["isChannel"] as? Bool) ?? false) }
            self.channelsTemplate?.updateSections([self.section(from: channels)])
            self.directMessagesTemplate?.updateSections([self.section(from: dms)])
        }
    }

    private func section(from rows: [[String: Any]]) -> CPListSection {
        guard !rows.isEmpty else {
            let empty = CPListItem(text: "No conversations", detailText: nil)
            return CPListSection(items: [empty])
        }
        let items = rows.map { row -> CPListTemplateItem in
            let convId = row["conversationId"] as? String ?? ""
            let name = row["displayName"] as? String ?? "Conversation"
            let last = row["lastText"] as? String
            let unread = (row["unreadCount"] as? NSNumber)?.intValue ?? 0

            let item = CPMessageListItem(
                conversationIdentifier: convId,
                text: name,
                leadingConfiguration: CPMessageListItemLeadingConfiguration(
                    leadingItem: .pin, leadingImage: nil, unread: unread > 0),
                trailingConfiguration: nil,
                detailText: unread > 0 ? "\(unread) unread" : last,
                trailingText: nil)

            // Read conversation: tap composes a new voice reply. Unread: leave
            // unset so tap triggers Siri read-back.
            if unread == 0 {
                item.phoneOrEmailAddress = "\(convId)\(IntentMessageConverters.handleDomain)"
            }
            return item
        }
        return CPListSection(items: items)
    }

    private func loadingSection() -> CPListSection {
        CPListSection(items: [CPListItem(text: "Loading…", detailText: nil)])
    }
}
