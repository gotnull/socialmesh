//
//  SendMessageIntent.swift
//  Runner
//
//  Socialmesh App Intents - Send a direct message to a node
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct SendMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Send a Direct Message"
    static var description = IntentDescription("Send a message to a Meshtastic node")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Message")
    var messageContent: String
    
    @Parameter(title: "Node ID", description: "The node ID in hex format (e.g., 9c3a29a9 or !9c3a29a9)")
    var nodeId: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$messageContent) to node \(\.$nodeId)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let nodeNumber = parseNodeId(nodeId) else {
            throw AppIntentError.nodeNotFound
        }
        
        do {
            _ = try await AppIntentsManager.shared.invokeIntentAsync(
                "sendMessage",
                parameters: [
                    "message": messageContent,
                    "nodeNum": nodeNumber
                ]
            )
            return .result(dialog: "Message sent to node \(nodeId)")
        } catch {
            throw AppIntentError.messageFailed
        }
    }
    
    /// Parse node ID from hex string (with or without ! prefix) to decimal Int
    private func parseNodeId(_ input: String) -> Int? {
        var hex = input.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("!") {
            hex = String(hex.dropFirst())
        }
        guard let value = UInt32(hex, radix: 16) else {
            return nil
        }
        return Int(value)
    }
}
