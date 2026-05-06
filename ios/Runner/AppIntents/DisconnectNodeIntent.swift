//
//  DisconnectNodeIntent.swift
//  Runner
//
//  SocialMesh App Intents - Disconnect from the current node
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct DisconnectNodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Disconnect Node"
    static var description = IntentDescription("Disconnect from the currently connected Meshtastic node")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            _ = try await AppIntentsManager.shared.invokeIntentAsync(
                "disconnectNode",
                parameters: [:]
            )
            return .result(dialog: "Disconnected from node")
        } catch {
            throw AppIntentError.flutterError("Failed to disconnect: \(error.localizedDescription)")
        }
    }
}
