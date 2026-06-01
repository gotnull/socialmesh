// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// watchOS side of the SocialMesh Watch companion bridge.
//
// Responsibilities:
//   1. Own the watchOS WCSession.default delegate.
//   2. Decode inbound `updateApplicationContext` payloads into
//      WatchSnapshot and push to WatchSnapshotStore.
//   3. Send outbound WatchIntent via sendMessage(_:replyHandler:errorHandler:)
//      and decode the reply into WatchIntentResult.
//   4. Synthesise stable WatchIntentResult rejections when the session
//      cannot reach the phone, so views always see a well-formed
//      response regardless of transport state.
//
// Stays protocol-blind: never inspects the snapshot beyond the
// envelope `version` key (and `init(from:)` already validated that).

import Foundation
import os
import WatchConnectivity

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
  @Published private(set) var isReachable: Bool = false
  @Published private(set) var activationState: WCSessionActivationState = .notActivated

  /// Diagnostic reasons used when the manager has to synthesise a
  /// local rejection. Kept narrow on purpose; application-level reasons
  /// (readiness_not_ready, channel_unavailable, ...) come from the
  /// phone-side `WatchSendFacade` and arrive as the real
  /// IntentResult's `diagnosticReason`.
  enum LocalDiagnosticReason {
    static let sessionUnsupported = "watch_session_unsupported"
    static let sessionUnreachable = "watch_session_unreachable"
    static let watchSendError = "watch_send_error"
    static let watchReplyMalformed = "watch_reply_malformed"
  }

  private weak var store: WatchSnapshotStore?
  private let log = Logger(
    subsystem: "com.gotnull.socialmesh", category: "watch")

  /// Wire the store. Called from the App's onAppear / init; idempotent.
  func attachStore(_ store: WatchSnapshotStore) {
    self.store = store
  }

  /// Activate the WCSession delegate. Safe to call multiple times: the
  /// framework treats a re-activate as a no-op when already activated.
  func activate() {
    guard WCSession.isSupported() else {
      log.log(level: .info,
              "WCSession unsupported on this device; bridge inert.")
      return
    }
    let session = WCSession.default
    if session.delegate !== self {
      session.delegate = self
    }
    if session.activationState != .activated {
      session.activate()
    }
    self.activationState = session.activationState
    self.isReachable = session.isReachable
    log.log(level: .info,
            "activate() called; state=\(self.activationState.rawValue, privacy: .public) reachable=\(self.isReachable, privacy: .public)")
    // If the session is already activated (e.g. re-activate on foreground),
    // pull whatever the phone last set so the UI never sits on
    // "Waiting for phone" while a cached snapshot exists.
    if session.activationState == .activated {
      applyReceivedContext(session)
      requestSnapshotRefresh()
    }
  }

  /// Decode and apply the phone's last-known applicationContext. The
  /// `didReceiveApplicationContext` delegate only fires for *new* contexts, so
  /// on cold start the most recent snapshot must be read explicitly from
  /// `receivedApplicationContext`.
  private func applyReceivedContext(_ session: WCSession) {
    let ctx = session.receivedApplicationContext
    guard !ctx.isEmpty else { return }
    do {
      let snap = try WatchSnapshot.decode(from: ctx)
      self.store?.update(snap)
      log.log(level: .info, "applied cached receivedApplicationContext")
    } catch {
      log.log(level: .error,
              "cached context decode failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// Ask the phone to push a fresh snapshot now. Fire-and-forget; the phone
  /// re-pushes via updateApplicationContext and the delegate applies it. No-op
  /// when the session is not reachable (the cached-context read covers that).
  func requestSnapshotRefresh() {
    guard WCSession.isSupported(), WCSession.default.isReachable else { return }
    Task { _ = await self.send(WatchIntent.refreshSnapshot()) }
  }

  /// Send an intent to the phone and await the reply. Returns a
  /// WatchIntentResult either decoded from the phone's reply or
  /// synthesised locally when the session cannot reach the phone.
  /// Guaranteed to return exactly one result; never throws.
  func send(_ intent: WatchIntent) async -> WatchIntentResult {
    guard WCSession.isSupported() else {
      log.log(level: .error,
              "send rejected: WCSession unsupported (req=\(intent.requestId, privacy: .public))")
      return self.localReject(
        for: intent, reason: LocalDiagnosticReason.sessionUnsupported)
    }
    let session = WCSession.default
    guard session.isReachable else {
      log.log(level: .error,
              "send rejected: session not reachable (req=\(intent.requestId, privacy: .public))")
      return self.localReject(
        for: intent, reason: LocalDiagnosticReason.sessionUnreachable)
    }

    let message: [String: Any]
    do {
      message = try intent.toMessage()
    } catch {
      log.log(level: .error,
              "send rejected: encode failed: \(error.localizedDescription, privacy: .public) req=\(intent.requestId, privacy: .public)")
      return self.localReject(
        for: intent, reason: LocalDiagnosticReason.watchReplyMalformed)
    }

    log.log(level: .info,
            "send: type=\(intent.type.rawValue, privacy: .public) channel=\(intent.target.channelIndex ?? -1, privacy: .public) canned=\(intent.payload.cannedKey ?? "", privacy: .public) req=\(intent.requestId, privacy: .public)")

    return await withCheckedContinuation { continuation in
      session.sendMessage(
        message,
        replyHandler: { [weak self] reply in
          guard let self = self else { return }
          Task { @MainActor in
            do {
              let result = try WatchIntentResult.decode(from: reply)
              self.store?.recordIntentResult(result)
              continuation.resume(returning: result)
            } catch {
              self.log.log(level: .error,
                           "reply decode failed: \(error.localizedDescription, privacy: .public) req=\(intent.requestId, privacy: .public)")
              let synth = self.localReject(
                for: intent,
                reason: LocalDiagnosticReason.watchReplyMalformed)
              self.store?.recordIntentResult(synth)
              continuation.resume(returning: synth)
            }
          }
        },
        errorHandler: { [weak self] err in
          guard let self = self else { return }
          Task { @MainActor in
            self.log.log(level: .error,
                         "sendMessage errorHandler: \(err.localizedDescription, privacy: .public) req=\(intent.requestId, privacy: .public)")
            let synth = self.localReject(
              for: intent,
              reason: LocalDiagnosticReason.watchSendError)
            self.store?.recordIntentResult(synth)
            continuation.resume(returning: synth)
          }
        }
      )
    }
  }

  private func localReject(
    for intent: WatchIntent,
    reason: String
  ) -> WatchIntentResult {
    return WatchIntentResult(
      requestId: intent.requestId,
      accepted: false,
      userVisibleReason: nil,
      diagnosticReason: reason,
      timestampMs: Int(Date().timeIntervalSince1970 * 1000)
    )
  }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      if let error = error {
        self.log.log(level: .error,
                     "WCSession activation error: \(error.localizedDescription, privacy: .public)")
      } else {
        self.log.log(level: .info,
                     "WCSession activated: state=\(activationState.rawValue, privacy: .public) reachable=\(session.isReachable, privacy: .public)")
      }
      self.activationState = activationState
      self.isReachable = session.isReachable
      if activationState == .activated {
        // Cold-start: grab the phone's last snapshot, then pull a fresh one.
        self.applyReceivedContext(session)
        self.requestSnapshotRefresh()
      }
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      self.log.log(level: .info,
                   "WCSession reachability: \(session.isReachable, privacy: .public)")
      self.isReachable = session.isReachable
      // Reachability flipping true is the moment the phone can hear a pull —
      // grab the cached context and ask for a fresh push.
      if session.isReachable {
        self.applyReceivedContext(session)
        self.requestSnapshotRefresh()
      }
    }
  }

  nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    Task { @MainActor in
      do {
        let snap = try WatchSnapshot.decode(from: applicationContext)
        self.store?.update(snap)
      } catch {
        self.log.log(level: .error,
                     "applicationContext decode failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}
