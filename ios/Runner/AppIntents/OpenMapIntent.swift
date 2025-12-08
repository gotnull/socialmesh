//
//  OpenMapIntent.swift
//  Runner
//
//  Socialmesh App Intents - Open the map view
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct OpenMapIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Map"
    static var description = IntentDescription("Open the Meshtastic map in Socialmesh")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & OpensIntent {
        _ = try? await AppIntentsManager.shared.invokeIntentAsync(
            "openMap",
            parameters: [:]
        )
        return .result()
    }
}
