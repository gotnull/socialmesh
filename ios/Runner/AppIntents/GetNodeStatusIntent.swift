//
//  GetNodeStatusIntent.swift
//  Runner
//
//  Socialmesh App Intents - Get status of a node
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct GetNodeStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Node Status"
    static var description = IntentDescription("Get the current status of a Meshtastic node")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Node ID", description: "The node ID in hex format (e.g., 9c3a29a9 or !9c3a29a9)")
    var nodeId: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get status of node \(\.$nodeId)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let nodeNumber = parseNodeId(nodeId) else {
            throw AppIntentError.nodeNotFound
        }
        
        do {
            let result = try await AppIntentsManager.shared.invokeIntentAsync(
                "getNodeStatus",
                parameters: ["nodeNum": nodeNumber]
            )
            
            if let data = result as? [String: Any] {
                let name = data["name"] as? String ?? "Unknown"
                let isOnline = data["isOnline"] as? Bool ?? false
                let battery = data["battery"] as? Int
                let lastSeen = data["lastSeen"] as? String ?? "Unknown"
                
                var status = "\(name): \(isOnline ? "Online" : "Offline")"
                if let battery = battery {
                    status += ", Battery: \(battery)%"
                }
                status += ", Last seen: \(lastSeen)"
                
                return .result(value: status, dialog: IntentDialog(stringLiteral: status))
            }
            
            return .result(value: "Node status unavailable", dialog: "Node status unavailable")
        } catch {
            throw AppIntentError.nodeNotFound
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
