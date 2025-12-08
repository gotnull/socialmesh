//
//  AppIntentErrors.swift
//  Runner
//
//  Socialmesh App Intents - Error definitions
//

import Foundation

@available(iOS 16, *)
enum AppIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notConnected
    case noNodes
    case nodeNotFound
    case messageFailed
    case flutterError(String)
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notConnected:
            return "Not connected to a Meshtastic node"
        case .noNodes:
            return "No nodes available"
        case .nodeNotFound:
            return "Node not found"
        case .messageFailed:
            return "Failed to send message"
        case .flutterError(let message):
            return LocalizedStringResource(stringLiteral: message)
        }
    }
}
