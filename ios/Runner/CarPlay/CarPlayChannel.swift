//
//  CarPlayChannel.swift
//  Runner
//
//  Flutter -> native bridge for the CarPlay communication writer.
//
//  The Dart-side CarPlayBridgeService builds the recent_messages / peers JSON
//  payloads and hands them to this channel; we persist them into the App Group
//  container via SharedContainer (the single Swift writer authority). The
//  SiriKit Intents extension reads those files from its own process.
//
//  Registering the handler is always safe: when the CARPLAY_COMMUNICATION_ENABLED
//  flag is off, Dart simply never invokes the channel.
//
//  Spec: docs/engineering/CARPLAY_COMMUNICATION_V0_1.md (sections 4 and 9.2).
//

import Foundation
import Flutter

final class CarPlayChannel {
    static let shared = CarPlayChannel()

    private var channel: FlutterMethodChannel?

    private init() {}

    func setup(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.socialmesh/carplay",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        self.channel = channel
        observeOutboxNotifications()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "writeRecentMessages":
            write(call.arguments, to: CarPlaySharedConfig.recentMessagesFile, result: result)
        case "writePeers":
            write(call.arguments, to: CarPlaySharedConfig.peersFile, result: result)
        case "readOutbox":
            readOutbox(result: result)
        case "removeDrainedItems":
            removeDrainedItems(call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Returns the raw outbox JSON (or nil when empty) for the Dart drain path.
    private func readOutbox(result: FlutterResult) {
        do {
            let json = try SharedContainer.shared.readRawJSON(
                from: CarPlaySharedConfig.outboxFile
            )
            result(json)
        } catch {
            result(FlutterError(
                code: "READ_FAILED",
                message: "Failed to read outbox: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    // Removes drained item ids from the outbox after the Dart side has sent them.
    private func removeDrainedItems(_ args: Any?, result: FlutterResult) {
        guard let ids = args as? [String] else {
            result(FlutterError(
                code: "BAD_ARGS",
                message: "Expected a list of item ids.",
                details: nil
            ))
            return
        }
        do {
            try SharedContainer.shared.removeOutboxItems(ids: Set(ids))
            result(nil)
        } catch {
            result(FlutterError(
                code: "REMOVE_FAILED",
                message: "Failed to remove outbox items: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    private func write(_ args: Any?, to file: String, result: FlutterResult) {
        guard let json = args as? String else {
            result(FlutterError(
                code: "BAD_ARGS",
                message: "Expected a JSON string payload for \(file).",
                details: nil
            ))
            return
        }
        do {
            try SharedContainer.shared.writeRawJSON(json, to: file)
            result(nil)
        } catch {
            result(FlutterError(
                code: "WRITE_FAILED",
                message: "Failed to write \(file): \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    // Observe the Darwin notification the Intents extension posts after writing
    // the outbox, and forward it to Dart as `outboxChanged` so a foregrounded
    // app drains promptly. Best-effort: if the Dart handler is not yet attached
    // the invoke is a harmless no-op. `shared` is a process-lifetime singleton,
    // so an unretained observer pointer is safe (never deallocated).
    private func observeOutboxNotifications() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                Unmanaged<CarPlayChannel>.fromOpaque(observer)
                    .takeUnretainedValue()
                    .notifyOutboxChanged()
            },
            CarPlaySharedConfig.outboxDarwinName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func notifyOutboxChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("outboxChanged", arguments: nil)
        }
    }
}
