//
//  RunAutomationIntent.swift
//  Runner
//
//  Socialmesh App Intents - Run an in-app automation by name
//

import Foundation
import AppIntents

@available(iOS 16.0, *)
struct RunAutomationIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Automation"
    static var description = IntentDescription("Run a Socialmesh automation by name")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Automation Name", description: "The name of the automation to run")
    var automationName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Run automation \(\.$automationName)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await AppIntentsManager.shared.invokeIntentAsync(
                "runAutomation",
                parameters: ["name": automationName]
            )
            
            if let data = result as? [String: Any],
               let executed = data["executed"] as? Bool,
               executed {
                return .result(dialog: "Automation '\(automationName)' executed successfully")
            } else if let data = result as? [String: Any],
                      let error = data["error"] as? String {
                return .result(dialog: IntentDialog(stringLiteral: error))
            }
            
            return .result(dialog: "Automation '\(automationName)' not found")
        } catch {
            throw AppIntentError.flutterError("Failed to run automation: \(error.localizedDescription)")
        }
    }
}

@available(iOS 16.0, *)
struct ListAutomationsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Automations"
    static var description = IntentDescription("Get a list of available Socialmesh automations")
    static var openAppWhenRun: Bool = false
    
    static var parameterSummary: some ParameterSummary {
        Summary("List available automations")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        do {
            let result = try await AppIntentsManager.shared.invokeIntentAsync(
                "listAutomations",
                parameters: [:]
            )
            
            if let data = result as? [String: Any],
               let automations = data["automations"] as? [[String: Any]] {
                if automations.isEmpty {
                    return .result(value: "No automations", dialog: "No automations configured")
                }
                
                let names = automations.compactMap { $0["name"] as? String }
                let list = names.joined(separator: ", ")
                let dialog = "Available automations: \(list)"
                
                return .result(value: list, dialog: IntentDialog(stringLiteral: dialog))
            }
            
            return .result(value: "None", dialog: "No automations found")
        } catch {
            throw AppIntentError.flutterError("Failed to list automations: \(error.localizedDescription)")
        }
    }
}
