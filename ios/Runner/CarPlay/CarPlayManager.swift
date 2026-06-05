//
//  CarPlayManager.swift
//  Runner
//
//  Native <-> Dart bridge for the in-process CarPlay communication feature.
//
//  The SiriKit intent handlers and the CarPlay scene run in the main app
//  process but the message store + radio live in Dart. This manager relays
//  requests to Dart over the com.socialmesh/carplay method channel and returns
//  Dart's reply to the caller's completion.
//
//  Cold-start safety: a CarPlay/Siri intent can fire before the FlutterEngine
//  has run (e.g. Siri triggering a launch). Invoking a channel before the
//  engine is ready throws, so outbound invocations are queued until Dart signals
//  "engineReady" (mirrors AppIntentsManager).
//
//  Spec: docs/engineering/CARPLAY_COMMUNICATION_V0_1.md.
//

import Flutter
import Foundation

final class CarPlayManager {
    static let shared = CarPlayManager()

    private var channel: FlutterMethodChannel?
    private let queue = DispatchQueue(label: "com.socialmesh.carplay-manager")
    private var engineReady = false
    private var pendingInvocations: [() -> Void] = []

    // Hard ceiling so a never-answering Dart side can't hang an intent forever.
    private let requestTimeout: TimeInterval = 8.0

    private init() {}

    func setup(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.socialmesh/carplay",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleDartCall(call, result: result)
        }
        self.channel = channel
    }

    // MARK: - Dart -> native

    private func handleDartCall(_ call: FlutterMethodCall, result: FlutterResult) {
        switch call.method {
        case "engineReady":
            markEngineReady()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func markEngineReady() {
        let drained: [() -> Void] = queue.sync {
            engineReady = true
            let q = pendingInvocations
            pendingInvocations.removeAll()
            return q
        }
        DispatchQueue.main.async { drained.forEach { $0() } }
    }

    // MARK: - native -> Dart

    /// Invoke a Dart-side handler and deliver its reply to `completion`.
    /// `completion` receives the Dart return value, or nil on error/timeout.
    /// Always invoked exactly once, on the main thread.
    func request(
        _ method: String,
        _ arguments: [String: Any],
        completion: @escaping (Any?) -> Void
    ) {
        var didComplete = false
        let finish: (Any?) -> Void = { value in
            DispatchQueue.main.async {
                if didComplete { return }
                didComplete = true
                completion(value)
            }
        }

        let invoke: () -> Void = { [weak self] in
            guard let self = self, let channel = self.channel else {
                finish(nil)
                return
            }
            channel.invokeMethod(method, arguments: arguments) { reply in
                if let error = reply as? FlutterError {
                    NSLog("CarPlayManager: \(method) failed: \(error.message ?? "")")
                    finish(nil)
                } else {
                    finish(reply)
                }
            }
        }

        let ready = queue.sync { engineReady }
        if ready {
            DispatchQueue.main.async(execute: invoke)
        } else {
            queue.sync { pendingInvocations.append(invoke) }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + requestTimeout) {
            finish(nil)
        }
    }
}
