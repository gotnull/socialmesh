//
//  ShutDownNodeIntent.swift
//  Runner
//
//  Socialmesh App Intents - Shut down the connected node
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct ShutDownNodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Shut Down Node"
    static var description = IntentDescription("Shut down the connected Meshtastic node")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(result: .result(dialog: "Shut down the connected node?"))

        do {
            _ = try await AppIntentsManager.shared.invokeIntentAsync(
                "shutdownNode",
                parameters: [:]
            )
            return .result(dialog: "Shutdown command sent")
        } catch {
            throw AppIntentError.flutterError("Failed to shut down node: \(error.localizedDescription)")
        }
    }
}
