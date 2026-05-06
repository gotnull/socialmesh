//
//  RestartNodeIntent.swift
//  Runner
//
//  SocialMesh App Intents - Restart/reboot the connected node
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct RestartNodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Restart Node"
    static var description = IntentDescription("Restart (reboot) the connected Meshtastic node")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(result: .result(dialog: "Restart the connected node?"))

        do {
            _ = try await AppIntentsManager.shared.invokeIntentAsync(
                "restartNode",
                parameters: [:]
            )
            return .result(dialog: "Restart command sent")
        } catch {
            throw AppIntentError.flutterError("Failed to restart node: \(error.localizedDescription)")
        }
    }
}
