import Flutter
import UIKit
import os

// Window UISceneDelegate for the phone app.
//
// Flutter 3.41 adopts the UIScene lifecycle: the FlutterViewController is no
// longer available in AppDelegate.didFinishLaunching (self.window is nil there).
// FlutterSceneDelegate creates the window + FlutterViewController from the Main
// storyboard during scene(_:willConnectTo:). We override that hook to register
// the app's native method channels once the controller exists — the same
// channels that previously lived in AppDelegate.
//
// A second scene role (CPTemplateApplicationSceneSessionRoleApplication ->
// CarPlaySceneDelegate) coexists with this one; both are declared in
// Info.plist under UIApplicationSceneManifest.
class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        registerChannels(on: controller)
    }

    // Registers every native -> Dart method channel the app relies on. Moved
    // verbatim from AppDelegate; the only change is the host (scene vs app
    // delegate). Channel handlers are registered eagerly; any that invoke Dart
    // (e.g. AppIntentsManager) already gate on their own engine-ready signal.
    private func registerChannels(on controller: FlutterViewController) {
        let messenger = controller.binaryMessenger

        // Native badge-reset channel. flutter_local_notifications' cancelAll()
        // does not reset UIApplication.applicationIconBadgeNumber; Dart calls
        // clearBadge here when the app foregrounds.
        let badgeChannel = FlutterMethodChannel(
            name: "socialmesh/badge",
            binaryMessenger: messenger
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

        // App Intents manager for Shortcuts integration.
        if #available(iOS 16.0, *) {
            AppIntentsManager.shared.setup(with: controller)
        }

        // Apple Watch companion bridge (com.socialmesh/watch_companion).
        WatchCompanionBridge.shared.setup(with: controller)

        // CarPlay in-process bridge (com.socialmesh/carplay): relays the SiriKit
        // intent handlers + CarPlay scene to Dart (ProtocolService, message store).
        CarPlayManager.shared.setup(with: controller)

        // Dart -> os_log bridge. Forwards debugPrint lines to os_log under
        // subsystem com.gotnull.socialmesh, category dart, so they surface in
        // simctl/log capture. Gated in Dart by kDebugMode.
        let dartLogger = Logger(subsystem: "com.gotnull.socialmesh", category: "dart")
        let osLogChannel = FlutterMethodChannel(
            name: "socialmesh/os_log",
            binaryMessenger: messenger
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
}
