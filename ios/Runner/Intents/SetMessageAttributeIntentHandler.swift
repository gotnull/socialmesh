//
//  SetMessageAttributeIntentHandler.swift
//  Runner
//
//  Handles INSetMessageAttributeIntent — Siri marking messages read/unread
//  after read-back. Relays to Dart, which updates the message store.
//

import Intents

final class SetMessageAttributeIntentHandler: NSObject, INSetMessageAttributeIntentHandling {
    func handle(
        intent: INSetMessageAttributeIntent,
        completion: @escaping (INSetMessageAttributeIntentResponse) -> Void
    ) {
        let activity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))

        // Only read/unread are meaningful for the mesh message store.
        let read: Bool
        switch intent.attribute {
        case .read: read = true
        case .unread: read = false
        default:
            completion(INSetMessageAttributeIntentResponse(code: .success, userActivity: activity))
            return
        }

        var args: [String: Any] = ["read": read]
        if let ids = intent.identifiers, !ids.isEmpty {
            args["identifiers"] = ids
        }

        CarPlayManager.shared.request("carplayMarkRead", args) { reply in
            let ok = (reply as? [String: Any])?["ok"] as? Bool ?? true
            completion(INSetMessageAttributeIntentResponse(
                code: ok ? .success : .failure, userActivity: activity))
        }
    }
}
