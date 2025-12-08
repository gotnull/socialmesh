//
//  AppIntentsManager.swift
//  Runner
//
//  Socialmesh App Intents - Manager for Flutter communication
//

import Foundation
import Flutter

@available(iOS 16.0, *)
class AppIntentsManager {
    static let shared = AppIntentsManager()
    
    private var methodChannel: FlutterMethodChannel?
    private var pendingCallbacks: [String: (Result<Any?, Error>) -> Void] = [:]
    
    private init() {}
    
    func setup(with controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: "com.socialmesh/app_intents",
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleFlutterCall(call: call, result: result)
        }
    }
    
    private func handleFlutterCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "intentResult":
            if let args = call.arguments as? [String: Any],
               let callbackId = args["callbackId"] as? String {
                let success = args["success"] as? Bool ?? false
                let error = args["error"] as? String
                
                if let callback = pendingCallbacks.removeValue(forKey: callbackId) {
                    if success {
                        callback(.success(args["data"]))
                    } else {
                        callback(.failure(AppIntentError.flutterError(error ?? "Unknown error")))
                    }
                }
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func invokeIntent(
        _ intentName: String,
        parameters: [String: Any],
        completion: @escaping (Result<Any?, Error>) -> Void
    ) {
        let callbackId = UUID().uuidString
        pendingCallbacks[callbackId] = completion
        
        var args = parameters
        args["intentName"] = intentName
        args["callbackId"] = callbackId
        
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("handleIntent", arguments: args)
        }
        
        // Timeout after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if let callback = self?.pendingCallbacks.removeValue(forKey: callbackId) {
                callback(.failure(AppIntentError.flutterError("Intent timed out")))
            }
        }
    }
    
    func invokeIntentAsync(_ intentName: String, parameters: [String: Any]) async throws -> Any? {
        return try await withCheckedThrowingContinuation { continuation in
            invokeIntent(intentName, parameters: parameters) { result in
                continuation.resume(with: result)
            }
        }
    }
}
