//
//  CarPlayDonation.swift
//  Runner
//
//  Donates INSendMessageIntent interactions (and, for incoming messages, posts
//  a Communication Notification) so mesh conversations appear in CarPlay's
//  Messages app and Siri can read them aloud / offer a voice reply.
//
//  Driven from Dart: CarPlayIntentService observes the message stream and calls
//  the com.socialmesh/carplay "donateMessage" method, which lands here. The
//  Communication Notification's `content.updating(from: intent)` requires the
//  com.apple.developer.usernotifications.communication entitlement.
//
//  Read-back tracking: the notification carries userInfo["carplay_repost"]=true
//  and threadIdentifier=conversationId; AppDelegate forwards a tap back to Dart
//  to mark the conversation read.
//

import Intents
import UserNotifications

enum CarPlayDonation {
    // Expected Dart args:
    //   conversationId (String), text (String), senderName (String),
    //   direction ("incoming"|"outgoing"), messageId (String),
    //   isChannel (Bool), channelName (String?).
    static func donate(_ args: [String: Any]) {
        guard let conversationId = args["conversationId"] as? String,
              let text = args["text"] as? String, !text.isEmpty else {
            return
        }
        let direction = args["direction"] as? String ?? "incoming"
        let senderName = args["senderName"] as? String ?? "Unknown"
        let isChannel = args["isChannel"] as? Bool ?? false
        let messageId = args["messageId"] as? String ?? conversationId

        let me = IntentMessageConverters.mePerson()
        let other = personFor(conversationId: conversationId, name: senderName, isChannel: isChannel)

        let intent: INSendMessageIntent
        let isIncoming = direction == "incoming"
        if isIncoming {
            intent = makeIntent(
                recipients: [me], sender: other, content: text,
                conversationId: conversationId, isChannel: isChannel, senderName: senderName)
        } else {
            intent = makeIntent(
                recipients: isChannel ? nil : [other], sender: me, content: text,
                conversationId: conversationId, isChannel: isChannel, senderName: senderName)
        }

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = isIncoming ? .incoming : .outgoing
        interaction.donate(completion: nil)

        if isIncoming {
            postCommunicationNotification(
                intent: intent, conversationId: conversationId,
                messageId: messageId, body: text)
        }
    }

    private static func makeIntent(
        recipients: [INPerson]?, sender: INPerson, content: String,
        conversationId: String, isChannel: Bool, senderName: String
    ) -> INSendMessageIntent {
        let groupName: INSpeakableString? = isChannel
            ? INSpeakableString(spokenPhrase: senderName) : nil
        return INSendMessageIntent(
            recipients: recipients,
            outgoingMessageType: .outgoingMessageText,
            content: content,
            speakableGroupName: groupName,
            conversationIdentifier: conversationId,
            serviceName: "SocialMesh",
            sender: sender,
            attachments: nil)
    }

    private static func postCommunicationNotification(
        intent: INSendMessageIntent, conversationId: String,
        messageId: String, body: String
    ) {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = nil
        content.threadIdentifier = conversationId
        content.userInfo["carplay_repost"] = true
        content.userInfo["conversationId"] = conversationId

        // Attaching the intent is what lets CarPlay/Siri treat this as a
        // communication notification (read-back) rather than a plain alert.
        guard let updated = try? content.updating(from: intent) else { return }
        let request = UNNotificationRequest(
            identifier: "carplay.read.\(conversationId).\(messageId)",
            content: updated, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func personFor(
        conversationId: String, name: String, isChannel: Bool
    ) -> INPerson {
        guard let t = IntentMessageConverters.parse(conversationId: conversationId) else {
            let handle = INPersonHandle(value: conversationId, type: .unknown)
            return INPerson(
                personHandle: handle, nameComponents: nil, displayName: name,
                image: nil, contactIdentifier: nil, customIdentifier: conversationId)
        }
        if t.kind == "channel" {
            return IntentMessageConverters.channelPerson(index: Int(t.value), name: name)
        }
        return IntentMessageConverters.dmPerson(nodeNum: t.value, displayName: name)
    }
}
