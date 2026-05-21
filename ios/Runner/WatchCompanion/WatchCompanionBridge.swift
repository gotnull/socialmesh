// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// WatchCompanionBridge — the Swift side of the Apple Watch companion.
//
// Responsibilities (kept narrow on purpose):
//
//  1. Own a single `WCSession.default` delegate. Only activated when
//     `WCSession.isSupported()` returns true (true on every iPhone, false
//     on iPad-only builds).
//  2. Bridge a FlutterMethodChannel named `com.socialmesh/watch_companion`.
//     Flutter is the driver; Swift is a transport. Method names:
//       Flutter → Swift:
//         - `activateSession`    : idempotent WCSession activate
//         - `deactivateSession`  : drop delegate; stop pushing context
//         - `pushSnapshot`       : forward dict to updateApplicationContext
//       Swift → Flutter:
//         - `onIntent`           : Watch sent a sendMessage; Dart returns
//                                  the WatchCompanionIntentResult JSON
//         - `onSessionStateChanged` : activation / reachability flip
//  3. Stay protocol-blind. Swift never inspects the snapshot dictionary
//     beyond the envelope `version` key; the Dart side owns all
//     application semantics.
//
// Safety:
//  - Every WCSessionDelegate callback dispatches MethodChannel work onto
//    the main queue (delegate callbacks fire on a private background
//    queue per Apple docs).
//  - Every MethodChannel invocation is guarded against a missing engine
//    so the bridge never crashes if Dart shut down mid-flight.
//  - `updateApplicationContext(_:)` throws (payload too large, etc.);
//    failures are logged and surfaced back to Dart, never silently lost.

import Foundation
import Flutter
import WatchConnectivity

final class WatchCompanionBridge: NSObject {
  static let shared = WatchCompanionBridge()

  private var methodChannel: FlutterMethodChannel?
  private var sessionActivated: Bool = false
  private var didLogSetup: Bool = false

  private override init() {
    super.init()
  }

  // MARK: - Setup

  /// Called once from AppDelegate after the FlutterViewController is up.
  /// Idempotent: a second call (after a Flutter hot-restart, say) just
  /// rewires the channel handler against the new BinaryMessenger.
  func setup(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: WatchCompanionWire.channelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    self.methodChannel = channel

    if !didLogSetup {
      didLogSetup = true
      WatchCompanionLog.info(
        "bridge setup: channel=\(WatchCompanionWire.channelName) wcSupported=\(WCSession.isSupported())"
      )
    }
  }

  // MARK: - Flutter → Swift dispatch

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "activateSession":
      activateIfPossible(result: result)

    case "deactivateSession":
      deactivate(result: result)

    case "pushSnapshot":
      handlePushSnapshot(call: call, result: result)

    default:
      WatchCompanionLog.warn("unknown method from Dart: \(call.method)")
      result(FlutterMethodNotImplemented)
    }
  }

  private func activateIfPossible(result: @escaping FlutterResult) {
    guard WCSession.isSupported() else {
      WatchCompanionLog.info(
        "activateSession ignored: WCSession unsupported on this device"
      )
      result(false)
      return
    }

    let session = WCSession.default
    if session.delegate == nil {
      session.delegate = self
    }
    if session.activationState != .activated {
      session.activate()
    }
    sessionActivated = true

    WatchCompanionLog.info(
      "activateSession requested (state=\(activationStateName(session.activationState)) "
      + "paired=\(session.isPaired) installed=\(session.isWatchAppInstalled) "
      + "reachable=\(session.isReachable))"
    )
    result(true)
  }

  private func deactivate(result: @escaping FlutterResult) {
    // WCSession does not expose a real deactivate path on iOS (only on
    // watchOS, and only when transitioning between watches). The
    // closest we can do is drop the delegate reference so we stop
    // forwarding callbacks. The framework's activation state survives.
    if WCSession.isSupported() {
      let session = WCSession.default
      if session.delegate === self {
        session.delegate = nil
      }
    }
    sessionActivated = false
    WatchCompanionLog.info("deactivateSession: delegate dropped")
    result(true)
  }

  private func handlePushSnapshot(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard WCSession.isSupported(), sessionActivated else {
      WatchCompanionLog.warn(
        "pushSnapshot ignored: session not active (supported=\(WCSession.isSupported()) "
        + "activated=\(sessionActivated))"
      )
      result(FlutterError(
        code: "session_inactive",
        message: "WCSession is not active",
        details: nil
      ))
      return
    }

    guard let dict = call.arguments as? [String: Any] else {
      WatchCompanionLog.warn("pushSnapshot ignored: arguments not a dictionary")
      result(FlutterError(
        code: "invalid_snapshot",
        message: "expected [String: Any] arguments",
        details: nil
      ))
      return
    }

    if let reason = WatchCompanionCodec.validateVersion(dict) {
      WatchCompanionLog.warn("pushSnapshot rejected: \(reason)")
      result(FlutterError(code: reason, message: reason, details: nil))
      return
    }

    let session = WCSession.default
    do {
      try session.updateApplicationContext(dict)
      let gen = (dict["generatedAt"] as? Int).map(String.init) ?? "?"
      WatchCompanionLog.info(
        "snapshot pushed via updateApplicationContext (gen=\(gen) "
        + "reachable=\(session.isReachable) paired=\(session.isPaired) "
        + "installed=\(session.isWatchAppInstalled))"
      )
      result(true)
    } catch {
      WatchCompanionLog.error(
        "updateApplicationContext threw: \(error.localizedDescription)"
      )
      result(FlutterError(
        code: "push_failed",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  // MARK: - Swift → Flutter dispatch (used by WCSessionDelegate)

  /// Forward a Watch-originated intent dictionary to Dart and bridge
  /// the IntentResult back to the supplied replyHandler. Guarantees
  /// exactly one replyHandler invocation per call, even on engine
  /// failure or malformed payload.
  private func forwardIntent(
    _ dict: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    let requestId = WatchCompanionCodec.extractRequestId(dict)
    WatchCompanionLog.info(
      "intent received from Watch (req=\(requestId) keys=\(dict.keys.sorted()))"
    )

    if let reason = WatchCompanionCodec.validateVersion(dict) {
      WatchCompanionLog.warn(
        "intent rejected at bridge: \(reason) req=\(requestId)"
      )
      replyHandler(WatchCompanionCodec.buildRejection(
        requestId: requestId,
        diagnosticReason: reason
      ))
      return
    }

    guard let channel = methodChannel else {
      WatchCompanionLog.warn(
        "intent dropped: Flutter channel not set up yet (req=\(requestId))"
      )
      replyHandler(WatchCompanionCodec.buildRejection(
        requestId: requestId,
        diagnosticReason: WatchCompanionWire.DiagnosticReason.bridgeNotReady
      ))
      return
    }

    channel.invokeMethod("onIntent", arguments: dict) { rawResult in
      if let flutterError = rawResult as? FlutterError {
        WatchCompanionLog.error(
          "Dart handler returned FlutterError "
          + "code=\(flutterError.code) msg=\(flutterError.message ?? "") req=\(requestId)"
        )
        replyHandler(WatchCompanionCodec.buildRejection(
          requestId: requestId,
          diagnosticReason: WatchCompanionWire.DiagnosticReason.flutterError
        ))
        return
      }
      if rawResult is FlutterMethodNotImplemented {
        WatchCompanionLog.error(
          "Dart handler returned FlutterMethodNotImplemented req=\(requestId)"
        )
        replyHandler(WatchCompanionCodec.buildRejection(
          requestId: requestId,
          diagnosticReason: WatchCompanionWire.DiagnosticReason.bridgeNotReady
        ))
        return
      }
      guard let resultDict = rawResult as? [String: Any] else {
        WatchCompanionLog.error(
          "Dart returned non-dictionary result (req=\(requestId)): \(String(describing: rawResult))"
        )
        replyHandler(WatchCompanionCodec.buildRejection(
          requestId: requestId,
          diagnosticReason: WatchCompanionWire.DiagnosticReason.flutterError
        ))
        return
      }
      let acceptedStr = (resultDict["accepted"] as? Bool).map { $0 ? "y" : "n" } ?? "?"
      let diag = (resultDict["diagnosticReason"] as? String) ?? ""
      WatchCompanionLog.info(
        "intent result for req=\(requestId): accepted=\(acceptedStr) diag=\(diag)"
      )
      replyHandler(resultDict)
    }
  }

  private func notifyStateChange(_ session: WCSession) {
    let payload: [String: Any] = [
      "activationState": activationStateName(session.activationState),
      "isReachable": session.isReachable,
      "isPaired": session.isPaired,
      "isWatchAppInstalled": session.isWatchAppInstalled,
    ]
    guard let channel = methodChannel else { return }
    channel.invokeMethod("onSessionStateChanged", arguments: payload)
  }

  private func activationStateName(_ state: WCSessionActivationState) -> String {
    switch state {
    case .notActivated: return "notActivated"
    case .inactive: return "inactive"
    case .activated: return "activated"
    @unknown default: return "unknown"
    }
  }
}

// MARK: - WCSessionDelegate

extension WatchCompanionBridge: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error = error {
      WatchCompanionLog.error(
        "WCSession activation error: \(error.localizedDescription)"
      )
    } else {
      WatchCompanionLog.info(
        "WCSession activated: state=\(activationStateName(activationState)) "
        + "paired=\(session.isPaired) installed=\(session.isWatchAppInstalled) "
        + "reachable=\(session.isReachable)"
      )
    }
    DispatchQueue.main.async { [weak self] in
      self?.notifyStateChange(session)
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    WatchCompanionLog.info(
      "WCSession reachability: \(session.isReachable) paired=\(session.isPaired)"
    )
    DispatchQueue.main.async { [weak self] in
      self?.notifyStateChange(session)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    WatchCompanionLog.info("WCSession became inactive")
    DispatchQueue.main.async { [weak self] in
      self?.notifyStateChange(session)
    }
  }

  func sessionDidDeactivate(_ session: WCSession) {
    WatchCompanionLog.info("WCSession deactivated; reactivating for next watch")
    // Required when the user switches paired watches: must reactivate
    // to receive messages from the new watch.
    WCSession.default.activate()
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.forwardIntent(message, replyHandler: replyHandler)
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    // The Watch always uses the replyHandler variant in v1 (every
    // intent expects a result). A bare didReceiveMessage means the
    // sender did not request a reply, so we just log and drop.
    WatchCompanionLog.warn(
      "didReceiveMessage (no replyHandler) ignored; v1 requires reply path. "
      + "keys=\(message.keys.sorted())"
    )
  }
}
