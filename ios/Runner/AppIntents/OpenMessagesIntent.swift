//
//  OpenMessagesIntent.swift
//  Runner
//
//  Socialmesh App Intents - Open the messages view
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct OpenMessagesIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Messages"
    static var description = IntentDescription("Open the messages view in Socialmesh")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & OpensIntent {
        _ = try? await AppIntentsManager.shared.invokeIntentAsync(
            "openMessages",
            parameters: [:]
        )
        return .result()
    }
}
