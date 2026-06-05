//
//  IntentMessageConverters.swift
//  Runner
//
//  Helpers shared by the SiriKit messaging intent handlers: conversation-id
//  scheme, INPerson / INMessage construction, and handle parsing. The data
//  itself comes from Dart over CarPlayManager; these converters only translate
//  between SiriKit types and the wire dictionaries.
//
//  Conversation id scheme (matches Dart + the spec):
//    - direct message: "dm-<nodeNum>"      handle "dm-<nodeNum>@socialmesh.local"
//    - channel:        "channel-<index>"   handle "channel-<index>@socialmesh.local"
//

import Intents

enum IntentMessageConverters {
    static let handleDomain = "@socialmesh.local"

    // MARK: - Conversation ids

    static func dmConversationId(nodeNum: Int64) -> String { "dm-\(nodeNum)" }
    static func channelConversationId(index: Int) -> String { "channel-\(index)" }

    static func dmHandle(nodeNum: Int64) -> String { "dm-\(nodeNum)\(handleDomain)" }
    static func channelHandle(index: Int) -> String { "channel-\(index)\(handleDomain)" }

    // MARK: - People

    static func mePerson() -> INPerson {
        let handle = INPersonHandle(value: "me", type: .unknown)
        return INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: "Me",
            image: nil,
            contactIdentifier: "me",
            customIdentifier: "me",
            isMe: true
        )
    }

    static func dmPerson(nodeNum: Int64, displayName: String) -> INPerson {
        let handle = INPersonHandle(value: dmHandle(nodeNum: nodeNum), type: .emailAddress)
        return INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: displayName,
            image: nil,
            contactIdentifier: String(nodeNum),
            customIdentifier: dmConversationId(nodeNum: nodeNum)
        )
    }

    static func channelPerson(index: Int, name: String) -> INPerson {
        let handle = INPersonHandle(value: channelHandle(index: index), type: .unknown)
        return INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: name,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: channelConversationId(index: index)
        )
    }

    // MARK: - Messages

    // Build an INMessage from a Dart message dictionary. Expected keys:
    //   id (String), text (String), tsMs (Int64), conversationId (String),
    //   senderName (String), sentByMe (Bool), isChannel (Bool).
    static func inMessage(from dict: [String: Any]) -> INMessage? {
        guard let id = dict["id"] as? String,
              let conversationId = dict["conversationId"] as? String else {
            return nil
        }
        let text = dict["text"] as? String ?? ""
        let tsMs = (dict["tsMs"] as? NSNumber)?.int64Value ?? 0
        let senderName = dict["senderName"] as? String ?? "Unknown"
        let sentByMe = dict["sentByMe"] as? Bool ?? false

        let me = mePerson()
        let other = personFor(conversationId: conversationId, displayName: senderName)
        let sender = sentByMe ? me : other
        let recipients = sentByMe ? [other] : [me]

        return INMessage(
            identifier: id,
            conversationIdentifier: conversationId,
            content: text,
            dateSent: Date(timeIntervalSince1970: Double(tsMs) / 1000.0),
            sender: sender,
            recipients: recipients,
            groupName: nil,
            messageType: .text
        )
    }

    // MARK: - Handle parsing

    // Resolve a recipient handle/displayName to a wire selector understood by
    // Dart. Returns ("dm", nodeNum) or ("channel", index), or nil.
    static func resolveTarget(from person: INPerson) -> (kind: String, value: Int64)? {
        if let custom = person.customIdentifier, let t = parse(conversationId: custom) {
            return t
        }
        if let handleValue = person.personHandle?.value, let t = parse(handleOrId: handleValue) {
            return t
        }
        return nil
    }

    static func parse(conversationId: String) -> (kind: String, value: Int64)? {
        parse(handleOrId: conversationId)
    }

    private static func parse(handleOrId raw: String) -> (kind: String, value: Int64)? {
        var s = raw
        if s.hasSuffix(handleDomain) { s = String(s.dropLast(handleDomain.count)) }
        if s.hasPrefix("dm-"), let n = Int64(s.dropFirst(3)) { return ("dm", n) }
        if s.hasPrefix("channel-"), let i = Int64(s.dropFirst(8)) { return ("channel", i) }
        return nil
    }

    private static func personFor(conversationId: String, displayName: String) -> INPerson {
        if let t = parse(conversationId: conversationId) {
            if t.kind == "dm" { return dmPerson(nodeNum: t.value, displayName: displayName) }
            return channelPerson(index: Int(t.value), name: displayName)
        }
        // Fallback: opaque handle.
        let handle = INPersonHandle(value: conversationId, type: .unknown)
        return INPerson(
            personHandle: handle, nameComponents: nil, displayName: displayName,
            image: nil, contactIdentifier: nil, customIdentifier: conversationId
        )
    }
}
