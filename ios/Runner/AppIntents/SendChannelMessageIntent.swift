//
//  SendChannelMessageIntent.swift
//  Runner
//
//  Socialmesh App Intents - Send a message to a channel
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct SendChannelMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Send a Channel Message"
    static var description = IntentDescription("Send a message to a Meshtastic channel")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Message")
    var messageContent: String
    
    @Parameter(title: "Channel Index", default: 0)
    var channelIndex: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$messageContent) to channel \(\.$channelIndex)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            _ = try await AppIntentsManager.shared.invokeIntentAsync(
                "sendChannelMessage",
                parameters: [
                    "message": messageContent,
                    "channelIndex": channelIndex
                ]
            )
            return .result(dialog: "Message sent to channel \(channelIndex)")
        } catch {
            throw AppIntentError.messageFailed
        }
    }
}
