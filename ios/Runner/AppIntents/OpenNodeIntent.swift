//
//  OpenNodeIntent.swift
//  Runner
//
//  Socialmesh App Intents - Open a specific node in the app
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct OpenNodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Node"
    static var description = IntentDescription("Open a Meshtastic node in Socialmesh")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Node ID", description: "The node ID in hex format (e.g., 9c3a29a9 or !9c3a29a9)")
    var nodeId: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Open node \(\.$nodeId)")
    }
    
    func perform() async throws -> some IntentResult & OpensIntent {
        guard let nodeNumber = parseNodeId(nodeId) else {
            throw AppIntentError.nodeNotFound
        }
        
        _ = try? await AppIntentsManager.shared.invokeIntentAsync(
            "openNode",
            parameters: ["nodeNum": nodeNumber]
        )
        return .result()
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
