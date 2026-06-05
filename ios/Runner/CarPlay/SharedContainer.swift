//
//  SharedContainer.swift
//  Runner / CarPlayIntents
//
//  Cross-process bridge for the CarPlay communication feature.
//
//  The SiriKit Intents extension runs in a separate process from the main app
//  and cannot reach ProtocolService or messages.db. All state shared between the
//  two processes flows through the App Group container as small JSON files,
//  read and written under an NSFileCoordinator so concurrent access from both
//  processes stays consistent.
//
//  This type has NO Flutter dependency on purpose: it must compile into both the
//  Runner target and the CarPlayIntents extension target. Add it to both targets'
//  membership.
//
//  Spec: docs/engineering/CARPLAY_COMMUNICATION_V0_1.md (sections 4 and 9.1).
//

import Foundation

// MARK: - App Group

enum CarPlaySharedConfig {
    // Existing App Group, already entitled in Runner.entitlements and used by
    // Live Activities. The extension target must also join it.
    static let appGroupId = "group.com.gotnull.socialmesh"

    // Darwin notification posted by the extension after it writes the outbox, so
    // a foregrounded main app drains promptly instead of waiting for the next
    // lifecycle trigger. Observed via CFNotificationCenterGetDarwinNotifyCenter.
    static let outboxDarwinName = "com.gotnull.socialmesh.outbox"

    static let outboxFile = "outbox.json"
    static let recentMessagesFile = "recent_messages.json"
    static let peersFile = "peers.json"
}

// MARK: - Wire models (mirror CARPLAY_COMMUNICATION_V0_1.md section 4)

struct CarPlayOutbox: Codable {
    var version: Int = 1
    var items: [CarPlayOutboxItem] = []
}

struct CarPlayOutboxItem: Codable {
    enum Kind: String, Codable {
        case send
        case markRead
    }

    // Idempotency key. The main app skips items it has already drained, so a
    // retried drain never double-sends.
    let id: String
    let kind: Kind
    let peerId: String
    // Present for `.send`; empty for `.markRead`.
    var text: String
    // Present for `.markRead`; the message id whose attribute changed.
    var messageId: String?
    // Extension-stamped. The extension cannot use a Flutter clock, so it stamps
    // with its own process time at enqueue.
    let createdAtMs: Int64
}

struct CarPlayRecentMessages: Codable {
    var version: Int = 1
    var updatedAtMs: Int64 = 0
    var conversations: [CarPlayConversation] = []
}

struct CarPlayConversation: Codable {
    let peerId: String
    let displayName: String
    var messages: [CarPlayMessage]
}

struct CarPlayMessage: Codable {
    let id: String
    let text: String
    let sentByMe: Bool
    let tsMs: Int64
    var read: Bool
}

struct CarPlayPeers: Codable {
    var version: Int = 1
    var peers: [CarPlayPeer] = []
}

struct CarPlayPeer: Codable {
    let peerId: String
    let displayName: String
}

// MARK: - Container access

enum SharedContainerError: Error {
    case appGroupUnavailable
    case coordinationFailed(Error)
}

final class SharedContainer {
    static let shared = SharedContainer()

    private let fileManager = FileManager.default
    private let coordinationQueue = DispatchQueue(
        label: "com.socialmesh.carplay.shared-container"
    )

    private init() {}

    private func containerURL() throws -> URL {
        guard let url = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: CarPlaySharedConfig.appGroupId
        ) else {
            throw SharedContainerError.appGroupUnavailable
        }
        return url
    }

    private func fileURL(_ name: String) throws -> URL {
        try containerURL().appendingPathComponent(name)
    }

    // MARK: Generic coordinated read / write

    // Decodes `T` from `name`. Returns `nil` when the file does not exist yet
    // (first run) rather than throwing, so callers can treat "no file" as empty.
    func read<T: Decodable>(_ type: T.Type, from name: String) throws -> T? {
        guard let data = try readData(from: name), !data.isEmpty else {
            return nil
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // Reads `name` as a raw UTF-8 JSON string for callers that forward bytes to
    // the Dart side rather than decoding natively. Returns nil when absent.
    func readRawJSON(from name: String) throws -> String? {
        guard let data = try readData(from: name), !data.isEmpty else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    // Shared coordinated read used by both the Codable and raw-string paths.
    // Returns nil when the file does not exist yet.
    private func readData(from name: String) throws -> Data? {
        let url = try fileURL(name)
        var readError: Error?
        var data: Data?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: url, options: [], error: nil
        ) { coordinatedURL in
            guard fileManager.fileExists(atPath: coordinatedURL.path) else {
                return
            }
            do {
                data = try Data(contentsOf: coordinatedURL)
            } catch {
                readError = error
            }
        }

        if let readError = readError {
            throw SharedContainerError.coordinationFailed(readError)
        }
        return data
    }

    // Atomically writes `value` to `name` under a write coordination so a reader
    // in the other process never sees a half-written file.
    func write<T: Encodable>(_ value: T, to name: String) throws {
        try writeData(JSONEncoder().encode(value), to: name)
    }

    // Writes a JSON string the main app already encoded (Dart-side payload
    // builders own the schema). Bytes are written verbatim under the same
    // coordination as `write<T>`; the extension decodes them via the Codable
    // models in this file.
    func writeRawJSON(_ json: String, to name: String) throws {
        try writeData(Data(json.utf8), to: name)
    }

    // Shared coordinated, atomic write used by both the Codable and raw-string
    // paths so a reader in the other process never sees a half-written file.
    private func writeData(_ data: Data, to name: String) throws {
        let url = try fileURL(name)
        var writeError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: url, options: .forReplacing, error: nil
        ) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }

        if let writeError = writeError {
            throw SharedContainerError.coordinationFailed(writeError)
        }
    }

    // Read-modify-write the outbox under a single serialized critical section so
    // two enqueues (or an enqueue racing the app's drain) cannot clobber each
    // other. The transform receives the current outbox (empty if none) and
    // returns the outbox to persist.
    func mutateOutbox(_ transform: (inout CarPlayOutbox) -> Void) throws {
        try coordinationQueue.sync {
            var outbox = (try read(CarPlayOutbox.self, from: CarPlaySharedConfig.outboxFile))
                ?? CarPlayOutbox()
            transform(&outbox)
            try write(outbox, to: CarPlaySharedConfig.outboxFile)
        }
    }

    // Removes the given item ids from the outbox after the main app has drained
    // them. Serialized via mutateOutbox so a concurrent enqueue is not lost.
    func removeOutboxItems(ids: Set<String>) throws {
        guard !ids.isEmpty else { return }
        try mutateOutbox { outbox in
            outbox.items.removeAll { ids.contains($0.id) }
        }
    }

    // MARK: Darwin signal

    // Posted by the extension after an outbox write. Cross-process wake only;
    // carries no payload (the payload is the outbox file itself).
    func postOutboxChanged() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(CarPlaySharedConfig.outboxDarwinName as CFString),
            nil, nil, true
        )
    }
}
