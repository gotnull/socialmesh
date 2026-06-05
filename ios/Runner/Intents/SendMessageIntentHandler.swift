//
//  SendMessageIntentHandler.swift
//  Runner
//
//  Handles INSendMessageIntent for CarPlay/Siri. Resolves the recipient to a
//  mesh node or channel, relays the send to Dart (ProtocolService.sendMessage),
//  and reports the honest result: .failureRequiringAppLaunch when the radio is
//  not connected (no optimistic queue — delivery requires the connected app).
//

import Intents

final class SendMessageIntentHandler: NSObject, INSendMessageIntentHandling {
    func resolveRecipients(
        for intent: INSendMessageIntent,
        with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void
    ) {
        guard let recipients = intent.recipients, !recipients.isEmpty else {
            completion([INSendMessageRecipientResolutionResult.needsValue()])
            return
        }
        let results = recipients.map { person -> INSendMessageRecipientResolutionResult in
            if IntentMessageConverters.resolveTarget(from: person) != nil {
                return .success(with: person)
            }
            return .unsupported()
        }
        completion(results)
    }

    func resolveContent(
        for intent: INSendMessageIntent,
        with completion: @escaping (INStringResolutionResult) -> Void
    ) {
        if let text = intent.content, !text.isEmpty {
            completion(.success(with: text))
        } else {
            completion(.needsValue())
        }
    }

    func handle(
        intent: INSendMessageIntent,
        completion: @escaping (INSendMessageIntentResponse) -> Void
    ) {
        let activity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))

        guard let text = intent.content, !text.isEmpty else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: activity))
            return
        }
        guard let recipient = intent.recipients?.first,
              let target = IntentMessageConverters.resolveTarget(from: recipient) else {
            completion(INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: activity))
            return
        }

        let args: [String: Any] = [
            "kind": target.kind,        // "dm" | "channel"
            "value": target.value,      // nodeNum | channelIndex
            "text": text,
        ]
        CarPlayManager.shared.request("carplaySend", args) { reply in
            let dict = reply as? [String: Any]
            let connected = dict?["connected"] as? Bool ?? false
            let sent = dict?["sent"] as? Bool ?? false
            let code: INSendMessageIntentResponseCode
            if sent {
                code = .success
            } else if !connected {
                // Radio not connected: tell the user to open the app. Honest,
                // not optimistic — a queue here could never transmit.
                code = .failureRequiringAppLaunch
            } else {
                code = .failure
            }
            completion(INSendMessageIntentResponse(code: code, userActivity: activity))
        }
    }
}
