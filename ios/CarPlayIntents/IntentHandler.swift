//
//  IntentHandler.swift
//  CarPlayIntents
//
//  SiriKit Intents extension principal class for the CarPlay communication
//  (text messaging) track. Implements the three Messages-domain intents Apple
//  requires for a CarPlay communication app:
//
//    - INSendMessageIntent        (send a message)
//    - INSearchForMessagesIntent  (request a list of messages)
//    - INSetMessageAttributeIntent (modify a message attribute / mark read)
//
//  Runs in a separate process from the main app. It cannot reach
//  ProtocolService or messages.db, so it bridges through the App Group
//  container via SharedContainer (add SharedContainer.swift to this target's
//  membership). Sends are enqueued to outbox.json and reported .success
//  immediately (optimistic-queue decision); the main app drains and delivers
//  on its next BLE connection.
//
//  Spec: docs/engineering/CARPLAY_COMMUNICATION_V0_1.md (sections 4, 5, 9.4).
//

import Intents

final class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        // A single object handles all three intents; SiriKit dispatches by type.
        return self
    }
}

// MARK: - Send a message

extension IntentHandler: INSendMessageIntentHandling {
    func handle(
        intent: INSendMessageIntent,
        completion: @escaping (INSendMessageIntentResponse) -> Void
    ) {
        let activity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))

        guard let text = intent.content, !text.isEmpty else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: activity))
            return
        }

        // Resolve the recipient to a node id via the peers mirror.
        guard let peerId = resolvePeerId(from: intent.recipients) else {
            // Unknown recipient: ask the system to launch the app so the user
            // can pick a peer. Never silently drop.
            completion(INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: activity))
            return
        }

        let item = CarPlayOutboxItem(
            id: UUID().uuidString,
            kind: .send,
            peerId: peerId,
            text: text,
            messageId: nil,
            createdAtMs: nowMs()
        )

        do {
            try SharedContainer.shared.mutateOutbox { outbox in
                outbox.items.append(item)
            }
            SharedContainer.shared.postOutboxChanged()
            // Optimistic: report success even though delivery is deferred until
            // the main app drains the queue on its next radio connection.
            completion(INSendMessageIntentResponse(code: .success, userActivity: activity))
        } catch {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: activity))
        }
    }

    // Resolve recipients up front so Siri can confirm before sending.
    func resolveRecipients(
        for intent: INSendMessageIntent,
        with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void
    ) {
        let recipients = intent.recipients ?? []
        guard !recipients.isEmpty else {
            completion([.needsValue()])
            return
        }
        let results = recipients.map { person -> INSendMessageRecipientResolutionResult in
            if resolvePeerId(from: [person]) != nil {
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
}

// MARK: - Search messages

extension IntentHandler: INSearchForMessagesIntentHandling {
    func handle(
        intent: INSearchForMessagesIntent,
        completion: @escaping (INSearchForMessagesIntentResponse) -> Void
    ) {
        let activity = NSUserActivity(activityType: NSStringFromClass(INSearchForMessagesIntent.self))
        let response = INSearchForMessagesIntentResponse(code: .success, userActivity: activity)

        guard let recent = try? SharedContainer.shared.read(
            CarPlayRecentMessages.self,
            from: CarPlaySharedConfig.recentMessagesFile
        ) else {
            response.messages = []
            completion(response)
            return
        }

        var messages: [INMessage] = []
        for convo in recent.conversations {
            let peer = person(id: convo.peerId, name: convo.displayName)
            let me = person(id: "me", name: "Me")
            for m in convo.messages {
                let sender = m.sentByMe ? me : peer
                let recipients = m.sentByMe ? [peer] : [me]
                messages.append(INMessage(
                    identifier: m.id,
                    content: m.text,
                    dateSent: Date(timeIntervalSince1970: Double(m.tsMs) / 1000.0),
                    sender: sender,
                    recipients: recipients
                ))
            }
        }

        response.messages = messages
        completion(response)
    }
}

// MARK: - Set message attribute (mark read)

extension IntentHandler: INSetMessageAttributeIntentHandling {
    func handle(
        intent: INSetMessageAttributeIntent,
        completion: @escaping (INSetMessageAttributeIntentResponse) -> Void
    ) {
        let activity = NSUserActivity(activityType: NSStringFromClass(INSetMessageAttributeIntent.self))

        // v0.1 reconciles read-state in the local mirror only. The durable
        // messages.db update rides the main app's normal read tracking; we do
        // not enqueue a markRead outbox op here (no consumer yet — see the
        // drain processor's v0.1 note).
        guard intent.attribute == .read || intent.attribute == .unread else {
            completion(INSetMessageAttributeIntentResponse(code: .success, userActivity: activity))
            return
        }

        let markRead = intent.attribute == .read
        let ids = Set(intent.identifiers ?? [])

        if !ids.isEmpty,
           var recent = try? SharedContainer.shared.read(
               CarPlayRecentMessages.self,
               from: CarPlaySharedConfig.recentMessagesFile
           ) {
            for c in recent.conversations.indices {
                for m in recent.conversations[c].messages.indices
                where ids.contains(recent.conversations[c].messages[m].id) {
                    recent.conversations[c].messages[m].read = markRead
                }
            }
            try? SharedContainer.shared.write(
                recent,
                to: CarPlaySharedConfig.recentMessagesFile
            )
        }

        completion(INSetMessageAttributeIntentResponse(code: .success, userActivity: activity))
    }
}

// MARK: - Helpers

private extension IntentHandler {
    func nowMs() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000.0)
    }

    // Map a resolved INPerson to a node id using the peers mirror. Matches on
    // the custom identifier first (set when we vend peers), then display name.
    func resolvePeerId(from recipients: [INPerson]?) -> String? {
        guard let recipients = recipients, !recipients.isEmpty else { return nil }
        let peers = (try? SharedContainer.shared.read(
            CarPlayPeers.self,
            from: CarPlaySharedConfig.peersFile
        ))?.peers ?? []

        for person in recipients {
            if let custom = person.customIdentifier,
               peers.contains(where: { $0.peerId == custom }) {
                return custom
            }
            if let handle = person.personHandle?.value,
               peers.contains(where: { $0.peerId == handle }) {
                return handle
            }
            if let name = person.displayName.isEmpty ? nil : person.displayName,
               let match = peers.first(where: { $0.displayName == name }) {
                return match.peerId
            }
        }
        return nil
    }

    func person(id: String, name: String) -> INPerson {
        return INPerson(
            personHandle: INPersonHandle(value: id, type: .unknown),
            nameComponents: nil,
            displayName: name,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: id
        )
    }
}
