import Flutter
import UIKit
import os

// Window UISceneDelegate for the phone app.
//
// Under the UIScene lifecycle the storyboard-backed FlutterViewController is
// created lazily on scene connect, spinning up an implicit FlutterEngine after
// the app has already finished launching. Plugins that register BGTaskScheduler
// launch handlers during registration then crash the process. To avoid that we
// drive the window from the single, pre-warmed engine owned by AppDelegate
// (created and registered during didFinishLaunching) instead of the storyboard.
//
// Because UIApplicationSupportsMultipleScenes is enabled (the CarPlay scene
// coexists), the engine must be manually registered with the scene for plugins
// to receive scene lifecycle events - registerSceneLifeCycleWithFlutterEngine.
// The inherited FlutterSceneDelegate methods then forward foreground/background,
// openURL, and userActivity callbacks to the registered engine's plugins.
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
        guard let windowScene = scene as? UIWindowScene,
              let engine = (UIApplication.shared.delegate as? AppDelegate)?.flutterEngine
        else {
            return
        }

        let controller = FlutterViewController(
            engine: engine,
            nibName: nil,
            bundle: nil
        )

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()

        // Wire scene lifecycle events (foreground/background, openURL,
        // userActivity) to the pre-warmed engine's plugins, and deliver the
        // launch connection options to them. Needed because the engine was
        // created outside the automatic scene-connect path.
        _ = registerSceneLifeCycle(with: engine)

        registerChannels(on: controller)
    }

    // Registers every native -> Dart method channel the app relies on. Moved
    // verbatim from AppDelegate; the only change is the host (scene vs app
    // delegate). Channel handlers are registered eagerly; any that invoke Dart
    // (e.g. AppIntentsManager) already gate on their own engine-ready signal.
    private func registerChannels(on controller: FlutterViewController) {
        let messenger = controller.binaryMessenger

        // Native badge channel. flutter_local_notifications' cancelAll()
        // does not reset UIApplication.applicationIconBadgeNumber; Dart calls
        // clearBadge here when the app foregrounds, and setBadge with the
        // unread-message total when messages arrive or the app backgrounds.
        let badgeChannel = FlutterMethodChannel(
            name: "socialmesh/badge",
            binaryMessenger: messenger
        )
        badgeChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "clearBadge":
                if #available(iOS 16.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(0) { _ in
                        result(nil)
                    }
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                    result(nil)
                }
            case "setBadge":
                guard let args = call.arguments as? [String: Any],
                      let count = args["count"] as? Int else {
                    result(FlutterError(
                        code: "bad_args",
                        message: "setBadge requires an integer 'count'",
                        details: nil
                    ))
                    return
                }
                if #available(iOS 16.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(count) { _ in
                        result(nil)
                    }
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = count
                    result(nil)
                }
            default:
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
