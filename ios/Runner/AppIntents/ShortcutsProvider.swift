//
//  ShortcutsProvider.swift
//  Runner
//
//  Socialmesh App Intents - Shortcuts provider for Siri integration
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct SocialmeshShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Send Direct Message
        AppShortcut(
            intent: SendMessageIntent(),
            phrases: [
                "Send a message with \(.applicationName)",
                "Message a node using \(.applicationName)",
                "Send \(.applicationName) message"
            ],
            shortTitle: "Send Message",
            systemImageName: "message"
        )
        
        // Send Channel Message
        AppShortcut(
            intent: SendChannelMessageIntent(),
            phrases: [
                "Send a channel message with \(.applicationName)",
                "Broadcast with \(.applicationName)",
                "Send to channel using \(.applicationName)"
            ],
            shortTitle: "Channel Message",
            systemImageName: "bubble.left.and.bubble.right"
        )
        
        // Get Node Status
        AppShortcut(
            intent: GetNodeStatusIntent(),
            phrases: [
                "Get node status from \(.applicationName)",
                "Check node with \(.applicationName)",
                "Node status using \(.applicationName)"
            ],
            shortTitle: "Node Status",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
        
        // Get Online Nodes
        AppShortcut(
            intent: GetOnlineNodesIntent(),
            phrases: [
                "How many nodes are online in \(.applicationName)",
                "Check online nodes with \(.applicationName)",
                "Get mesh status from \(.applicationName)"
            ],
            shortTitle: "Online Nodes",
            systemImageName: "network"
        )
        
        // Open Node
        AppShortcut(
            intent: OpenNodeIntent(),
            phrases: [
                "Open node in \(.applicationName)",
                "Show node using \(.applicationName)",
                "View node with \(.applicationName)"
            ],
            shortTitle: "Open Node",
            systemImageName: "person.circle"
        )
        
        // Open Map
        AppShortcut(
            intent: OpenMapIntent(),
            phrases: [
                "Open map in \(.applicationName)",
                "Show mesh map using \(.applicationName)",
                "View map with \(.applicationName)"
            ],
            shortTitle: "Open Map",
            systemImageName: "map"
        )
        
        // Open Messages
        AppShortcut(
            intent: OpenMessagesIntent(),
            phrases: [
                "Open messages in \(.applicationName)",
                "Show messages using \(.applicationName)",
                "View messages with \(.applicationName)"
            ],
            shortTitle: "Open Messages",
            systemImageName: "message"
        )
    }
}
