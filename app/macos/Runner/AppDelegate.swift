import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  private static var pendingAppLinks: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = self
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.scheme == "downpeed" {
      if let window = application.windows.compactMap({ $0 as? MainFlutterWindow }).first {
        window.acceptAppLink(url.absoluteString)
      } else {
        Self.pendingAppLinks.append(url.absoluteString)
      }
    }
  }

  static func takePendingAppLinks() -> [String] {
    let links = pendingAppLinks
    pendingAppLinks.removeAll(keepingCapacity: false)
    return links
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      for window in NSApp.windows where !window.isVisible {
        window.makeKeyAndOrderFront(self)
      }
      NSApp.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
