//
//  IntentHandler.swift
//  Runner
//
//  In-process SiriKit intent router. The app delegate's
//  application(_:handlerFor:) returns handler(for:), which dispatches each
//  Messages-domain intent to its handler. No separate Intents extension target:
//  the handlers reach the message store + radio through Dart (CarPlayManager),
//  which only exists in the main app process.
//

import Intents

final class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any? {
        switch intent {
        case is INSendMessageIntent:
            return SendMessageIntentHandler()
        case is INSearchForMessagesIntent:
            return SearchForMessagesIntentHandler()
        case is INSetMessageAttributeIntent:
            return SetMessageAttributeIntentHandler()
        default:
            return nil
        }
    }
}
