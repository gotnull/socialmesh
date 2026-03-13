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
        if call.method == "clearBadge" {
          NSApplication.shared.dockTile.badgeLabel = nil
          result(nil)
        } else {
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
