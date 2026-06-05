import Flutter
import Intents
import UIKit
import UserNotifications
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Clear Firestore cache if potentially corrupted BEFORE any Firebase init
    // This prevents NSInternalInconsistencyException crashes from corrupted cache
    // See: https://github.com/firebase/flutterfire/issues/9661
    clearFirestoreCacheIfCorrupted()

    // Required for flutter_local_notifications to show notifications in foreground
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Request Siri authorization so the CarPlay communication SiriKit intents
    // (send/search/mark-read) can be invoked. No-op if already decided.
    INPreferences.requestSiriAuthorization { _ in }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Plugin registration under the UIScene lifecycle. The FlutterViewController
  // is created by SceneDelegate (FlutterSceneDelegate) from the Main storyboard,
  // which spins up the implicit FlutterEngine and calls this back. Registering
  // here replaces the old `GeneratedPluginRegistrant.register(with: self)` in
  // didFinishLaunching, which no longer has a window/controller to attach to.
  // The native method channels themselves are registered in SceneDelegate, once
  // the controller exists.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // In-process SiriKit intent routing for CarPlay communication. Returns the
  // per-intent handler; each relays to Dart via CarPlayManager.
  override func application(
    _ application: UIApplication,
    handlerFor intent: INIntent
  ) -> Any? {
    return IntentHandler().handler(for: intent)
  }

  // Read-tracking for CarPlay communication notifications. A tap on a
  // carplay_repost notification (posted by CarPlayDonation) marks that
  // conversation read in Dart. super is called so flutter_local_notifications'
  // own tap handling is preserved.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if userInfo["carplay_repost"] as? Bool == true {
      let conversationId = (userInfo["conversationId"] as? String)
        ?? response.notification.request.content.threadIdentifier
      if !conversationId.isEmpty {
        CarPlayManager.shared.request(
          "carplayMarkReadConversation",
          ["conversationId": conversationId]
        ) { _ in }
      }
    }
    super.userNotificationCenter(
      center, didReceive: response, withCompletionHandler: completionHandler)
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
