import Cocoa
import FlutterMacOS
import ServiceManagement
import UserNotifications

class MainFlutterWindow: NSWindow {
  private static let desktopActionsChannel = "com.xiaoxi.downpeed/desktop_actions"
  private static let startupChannel = "com.xiaoxi.downpeed/startup"
  private static let startupArgument = "--downpeed-startup"

  override func awakeFromNib() {
    let launchedAtLogin = Self.wasLaunchedAsLoginItem
    let project = FlutterDartProject()
    if launchedAtLogin {
      project.dartEntrypointArguments = [Self.startupArgument]
    }
    let flutterViewController = FlutterViewController(project: project)
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    configureImmersiveTitlebar()

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerDesktopActions(with: flutterViewController)
    registerStartupActions(with: flutterViewController)

    super.awakeFromNib()
    if launchedAtLogin {
      orderOut(nil)
    }
  }

  private static var wasLaunchedAsLoginItem: Bool {
    guard let event = NSAppleEventManager.shared().currentAppleEvent else {
      return false
    }
    return event.eventClass == kCoreEventClass &&
      event.eventID == kAEOpenApplication &&
      event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
  }

  private func configureImmersiveTitlebar() {
    title = ""
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = true
    backgroundColor = .windowBackgroundColor
    if #available(macOS 11.0, *) {
      titlebarSeparatorStyle = .none
    }
  }

  private func registerDesktopActions(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.desktopActionsChannel,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Desktop actions are unavailable.", details: nil))
        return
      }
      switch call.method {
      case "openFile":
        self.openFile(arguments: call.arguments, result: result)
      case "revealFile":
        self.revealFile(arguments: call.arguments, result: result)
      case "showCompletionNotification":
        self.showCompletionNotification(arguments: call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerStartupActions(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.startupChannel,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard #available(macOS 13.0, *) else {
        if call.method == "isSupported" {
          result(false)
        } else {
          result(FlutterError(
            code: "unsupported",
            message: "Login launch requires macOS 13 or later.",
            details: nil
          ))
        }
        return
      }
      let service = SMAppService.mainApp
      switch call.method {
      case "isSupported":
        result(true)
      case "isEnabled":
        result(service.status == .enabled)
      case "setEnabled":
        guard let enabled = call.arguments as? Bool else {
          result(FlutterError(
            code: "invalid_argument",
            message: "A login launch value is required.",
            details: nil
          ))
          return
        }
        do {
          if enabled {
            try service.register()
          } else if service.status != .notRegistered {
            try service.unregister()
          }
          result((service.status == .enabled) == enabled)
        } catch {
          result(FlutterError(
            code: "startup_update_failed",
            message: "The system login item could not be updated.",
            details: nil
          ))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func fileURL(from arguments: Any?) throws -> URL {
    guard
      let values = arguments as? [String: Any],
      let path = values["path"] as? String,
      !path.isEmpty,
      !path.contains("\0"),
      (path as NSString).isAbsolutePath
    else {
      throw DesktopActionFailure.invalidArgument
    }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
          !isDirectory.boolValue else {
      throw DesktopActionFailure.fileNotFound
    }
    return URL(fileURLWithPath: path)
  }

  private func openFile(arguments: Any?, result: @escaping FlutterResult) {
    do {
      let url = try fileURL(from: arguments)
      guard NSWorkspace.shared.open(url) else {
        result(DesktopActionFailure.openFailed.flutterError)
        return
      }
      result(nil)
    } catch let failure as DesktopActionFailure {
      result(failure.flutterError)
    } catch {
      result(DesktopActionFailure.openFailed.flutterError)
    }
  }

  private func revealFile(arguments: Any?, result: @escaping FlutterResult) {
    do {
      let url = try fileURL(from: arguments)
      NSWorkspace.shared.activateFileViewerSelecting([url])
      result(nil)
    } catch let failure as DesktopActionFailure {
      result(failure.flutterError)
    } catch {
      result(DesktopActionFailure.openFailed.flutterError)
    }
  }

  private func showCompletionNotification(
    arguments: Any?,
    result: @escaping FlutterResult
  ) {
    guard
      let values = arguments as? [String: Any],
      let id = values["id"] as? String,
      let title = values["title"] as? String,
      let body = values["body"] as? String,
      !id.isEmpty,
      !title.isEmpty,
      !body.isEmpty
    else {
      result(DesktopActionFailure.invalidArgument.flutterError)
      return
    }

    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      guard error == nil, granted else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "notification_denied",
            message: "Completion notifications are not allowed.",
            details: nil
          ))
        }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      let request = UNNotificationRequest(
        identifier: "downpeed.completed.\(id)",
        content: content,
        trigger: nil
      )
      center.add(request) { addError in
        DispatchQueue.main.async {
          if addError == nil {
            result(nil)
          } else {
            result(FlutterError(
              code: "notification_unavailable",
              message: "The completion notification could not be delivered.",
              details: nil
            ))
          }
        }
      }
    }
  }
}

private enum DesktopActionFailure: Error {
  case invalidArgument
  case fileNotFound
  case openFailed

  var flutterError: FlutterError {
    switch self {
    case .invalidArgument:
      return FlutterError(code: "invalid_argument", message: "An absolute file path is required.", details: nil)
    case .fileNotFound:
      return FlutterError(code: "file_not_found", message: "The completed file no longer exists.", details: nil)
    case .openFailed:
      return FlutterError(code: "open_failed", message: "The system could not open the completed file.", details: nil)
    }
  }
}
