//
//  SearchForMessagesIntentHandler.swift
//  Runner
//
//  Handles INSearchForMessagesIntent — Siri asking for a list of messages
//  (e.g. "read my unread messages"). Relays the query to Dart and maps the
//  returned message dictionaries to [INMessage].
//

import Intents

final class SearchForMessagesIntentHandler: NSObject, INSearchForMessagesIntentHandling {
    func handle(
        intent: INSearchForMessagesIntent,
        completion: @escaping (INSearchForMessagesIntentResponse) -> Void
    ) {
        let activity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))

        var args: [String: Any] = [:]
        if let convoIds = intent.conversationIdentifiers, !convoIds.isEmpty {
            args["conversationIds"] = convoIds
        }
        if intent.attributes.contains(.unread) {
            args["unread"] = true
        } else if intent.attributes.contains(.read) {
            args["unread"] = false
        }

        CarPlayManager.shared.request("carplaySearch", args) { reply in
            let response = INSearchForMessagesIntentResponse(code: .success, userActivity: activity)
            if let rows = reply as? [[String: Any]] {
                response.messages = rows.compactMap { IntentMessageConverters.inMessage(from: $0) }
            } else {
                response.messages = []
            }
            completion(response)
        }
    }
}
