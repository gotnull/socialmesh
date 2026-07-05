import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Native badge-reset channel.
    // flutter_local_notifications' cancelAll() removes delivered notifications
    // from the notification centre but does NOT reset the dock badge.
    // Dart calls clearBadge via this channel whenever the app comes to the
    // foreground so the dock badge is cleared even when set by an APNs payload.
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let badgeChannel = FlutterMethodChannel(
        name: "socialmesh/badge",
        binaryMessenger: controller.engine.binaryMessenger
      )
      badgeChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "clearBadge":
          NSApplication.shared.dockTile.badgeLabel = nil
          result(nil)
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
          NSApplication.shared.dockTile.badgeLabel = count > 0 ? String(count) : nil
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
