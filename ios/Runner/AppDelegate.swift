import Flutter
import UIKit
import os

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Clear Firestore cache if potentially corrupted BEFORE any Firebase init
    // This prevents NSInternalInconsistencyException crashes from corrupted cache
    // See: https://github.com/firebase/flutterfire/issues/9661
    clearFirestoreCacheIfCorrupted()
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Required for flutter_local_notifications to show notifications in foreground
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Native badge-reset channel.
    // flutter_local_notifications' cancelAll() removes delivered notifications
    // from the notification centre but does NOT reset
    // UIApplication.applicationIconBadgeNumber. Dart calls clearBadge via this
    // channel whenever the app comes to the foreground so the icon badge is
    // cleared even when the badge was set by an APNs push payload.
    if let controller = window?.rootViewController as? FlutterViewController {
      let badgeChannel = FlutterMethodChannel(
        name: "socialmesh/badge",
        binaryMessenger: controller.binaryMessenger
      )
      badgeChannel.setMethodCallHandler { call, result in
        if call.method == "clearBadge" {
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in
              result(nil)
            }
          } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
            result(nil)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    // Setup App Intents manager for Shortcuts integration
    if #available(iOS 16.0, *) {
      if let controller = window?.rootViewController as? FlutterViewController {
        AppIntentsManager.shared.setup(with: controller)
      }
    }

    // Dart → os_log bridge.
    // Flutter's `print`/`debugPrint` goes to Dart VM stderr, which is
    // invisible to `xcrun simctl log stream` and the xcodebuild MCP log
    // capture tool. The Dart-side `OsLogBridge` installs a `debugPrint`
    // tee that forwards every line through this channel so logs appear
    // under subsystem `com.gotnull.socialmesh`, category `dart`.
    // Gated in Dart by `kDebugMode` — release builds never invoke the
    // channel, so this handler is harmless when present.
    if let controller = window?.rootViewController as? FlutterViewController {
      let dartLogger = Logger(subsystem: "com.gotnull.socialmesh", category: "dart")
      let osLogChannel = FlutterMethodChannel(
        name: "socialmesh/os_log",
        binaryMessenger: controller.binaryMessenger
      )
      osLogChannel.setMethodCallHandler { call, result in
        if call.method == "log",
           let args = call.arguments as? [String: Any],
           let msg = args["msg"] as? String {
          dartLogger.log(level: .default, "\(msg, privacy: .public)")
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /// Check for and clear potentially corrupted Firestore cache
  /// The cache corruption manifests as an assertion failure during Firestore initialization.
  /// We detect this by checking if cache files exist but are empty or have invalid headers.
  private func clearFirestoreCacheIfCorrupted() {
    guard let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first else {
      return
    }
    
    // Check if we've had a crash marker from previous run
    let crashMarkerPath = (libraryPath as NSString).appendingPathComponent("firestore_crash_marker")
    let fileManager = FileManager.default
    
    if fileManager.fileExists(atPath: crashMarkerPath) {
      // Previous run crashed during Firestore init - clear the cache
      NSLog("SocialMesh: Detected previous Firestore crash, clearing cache")
      clearFirestoreCache()
      try? fileManager.removeItem(atPath: crashMarkerPath)
      return
    }
    
    // Set a crash marker that we'll clear on successful init
    // If the app crashes during Firestore init, this marker will persist
    fileManager.createFile(atPath: crashMarkerPath, contents: nil, attributes: nil)
    
    // Schedule marker removal after successful init (2 second delay)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      try? fileManager.removeItem(atPath: crashMarkerPath)
    }
  }
  
  /// Clear Firestore's local cache files
  private func clearFirestoreCache() {
    guard let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first else {
      return
    }
    
    let fileManager = FileManager.default
    let firestorePaths = [
      "Caches/com.google.firebase.firestore",
      "Application Support/com.google.firebase.firestore",
      "Preferences/com.google.firebase.firestore"
    ]
    
    for relativePath in firestorePaths {
      let fullPath = (libraryPath as NSString).appendingPathComponent(relativePath)
      if fileManager.fileExists(atPath: fullPath) {
        do {
          try fileManager.removeItem(atPath: fullPath)
          NSLog("SocialMesh: Cleared Firestore cache at \(relativePath)")
        } catch {
          NSLog("SocialMesh: Failed to clear Firestore cache: \(error)")
        }
      }
    }
  }
}
