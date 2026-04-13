//
//  AppIntentsManager.swift
//  Runner
//
//  Socialmesh App Intents - Manager for Flutter communication
//
//  Engine-readiness gate: App Intents with `openAppWhenRun = false` can fire
//  before the FlutterEngine has finished initialising (e.g. Siri Shortcuts
//  triggering a cold-start). Calling `invokeMethod` on a channel whose engine
//  hasn't run yet throws:
//
//      NSInternalInconsistencyException –
//      "Sending a message before the FlutterEngine has been run."
//
//  To prevent this, all outbound method-channel calls are queued until the
//  Dart side signals readiness via the "engineReady" method call.  The
//  Dart-side `AppIntentsService.setup()` must invoke "engineReady" on the
//  `com.socialmesh/app_intents` channel once the provider tree is live.
//

import Foundation
import Flutter

@available(iOS 16.0, *)
class AppIntentsManager {
    static let shared = AppIntentsManager()

    private var methodChannel: FlutterMethodChannel?
    private var pendingCallbacks: [String: (Result<Any?, Error>) -> Void] = [:]
    private let queue = DispatchQueue(label: "com.socialmesh.app-intents-manager")

    // -----------------------------------------------------------------------
    // Engine-readiness gate
    // -----------------------------------------------------------------------

    /// Whether the Flutter engine (Dart isolate) has signalled that it is ready
    /// to receive method-channel calls.
    private var _engineReady = false

    /// Invocations that arrived before the engine was ready.  They are drained
    /// in FIFO order as soon as `markEngineReady()` is called.
    private var pendingInvocations: [() -> Void] = []

    private init() {}

    // MARK: - Setup

    func setup(with controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: "com.socialmesh/app_intents",
            binaryMessenger: controller.binaryMessenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleFlutterCall(call: call, result: result)
        }
    }

    /// Called when the Dart side signals readiness (via the "engineReady"
    /// method call).  Drains any queued invocations in FIFO order.
    func markEngineReady() {
        queue.sync {
            _engineReady = true
        }

        // Drain the queue on the main thread (method-channel calls must happen
        // on the platform thread).
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let invocations = self.queue.sync { () -> [() -> Void] in
                let queued = self.pendingInvocations
                self.pendingInvocations.removeAll()
                return queued
            }
            for invocation in invocations {
                invocation()
            }
        }
    }

    /// Returns `true` when the Dart isolate has signalled readiness.
    var isEngineReady: Bool {
        queue.sync { _engineReady }
    }

    // MARK: - Flutter -> Native calls

    private func handleFlutterCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "engineReady":
            // Dart side signals that the provider tree is live.
            markEngineReady()
            result(nil)

        case "intentResult":
            if let args = call.arguments as? [String: Any],
               let callbackId = args["callbackId"] as? String {
                let success = args["success"] as? Bool ?? false
                let error = args["error"] as? String

                let callback = queue.sync { pendingCallbacks.removeValue(forKey: callbackId) }
                if let callback = callback {
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

    // MARK: - Native -> Flutter calls

    func invokeIntent(
        _ intentName: String,
        parameters: [String: Any],
        completion: @escaping (Result<Any?, Error>) -> Void
    ) {
        let callbackId = UUID().uuidString
        queue.sync { pendingCallbacks[callbackId] = completion }

        var args = parameters
        args["intentName"] = intentName
        args["callbackId"] = callbackId

        // Build the actual channel invocation as a closure so it can be
        // dispatched immediately (engine ready) or queued (engine not ready).
        let doInvoke: () -> Void = { [weak self] in
            self?.methodChannel?.invokeMethod("handleIntent", arguments: args)
        }

        let ready = queue.sync { _engineReady }

        if ready {
            // Engine is running - send immediately on the main thread.
            DispatchQueue.main.async {
                doInvoke()
            }
        } else {
            // Engine not ready - park the invocation until markEngineReady().
            NSLog("Socialmesh: AppIntentsManager queuing intent '%@' (engine not ready)", intentName)
            queue.sync {
                pendingInvocations.append(doInvoke)
            }
        }

        // Timeout after 30 seconds regardless of engine state.
        // If the engine never becomes ready the intent will still fail
        // gracefully rather than hanging forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self else { return }
            let callback = self.queue.sync { self.pendingCallbacks.removeValue(forKey: callbackId) }
            if let callback = callback {
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
