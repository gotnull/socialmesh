//
//  GetOnlineNodesIntent.swift
//  Runner
//
//  Socialmesh App Intents - Get count of online nodes
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct GetOnlineNodesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Online Nodes"
    static var description = IntentDescription("Get the number of online Meshtastic nodes")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        do {
            let result = try await AppIntentsManager.shared.invokeIntentAsync(
                "getOnlineNodes",
                parameters: [:]
            )
            
            if let data = result as? [String: Any],
               let count = data["count"] as? Int {
                let message = count == 1 ? "1 node online" : "\(count) nodes online"
                return .result(value: count, dialog: IntentDialog(stringLiteral: message))
            }
            
            return .result(value: 0, dialog: "No nodes online")
        } catch {
            throw AppIntentError.noNodes
        }
    }
}
