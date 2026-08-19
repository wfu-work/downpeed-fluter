import Cocoa
import FlutterMacOS
import ServiceManagement
import Security
import UserNotifications

class MainFlutterWindow: NSWindow {
  private static let desktopActionsChannel = "com.xiaoxi.downpeed/desktop_actions"
  private static let startupChannel = "com.xiaoxi.downpeed/startup"
  private static let secureStorageChannel = "com.xiaoxi.downpeed/secure_storage"
  private static let appLinksChannel = "com.xiaoxi.downpeed/app_links"
  private static let secureStorageKey = "proxy-password"
  private static let keychainService = "com.xiaoxi.downpeed.proxy"
  private static let startupArgument = "--downpeed-startup"
  private var appLinkChannel: FlutterMethodChannel?
  private var pendingAppLinks: [String] = []
  private var appLinksReady = false

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
    registerSecureStorage(with: flutterViewController)
    registerAppLinks(with: flutterViewController)

    super.awakeFromNib()
    for uri in AppDelegate.takePendingAppLinks() {
      acceptAppLink(uri)
    }
    if launchedAtLogin {
      orderOut(nil)
    }
  }

  func acceptAppLink(_ uri: String) {
    if appLinksReady, let channel = appLinkChannel {
      channel.invokeMethod("openUri", arguments: uri)
    } else {
      pendingAppLinks.append(uri)
    }
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func registerAppLinks(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.appLinksChannel,
      binaryMessenger: controller.engine.binaryMessenger
    )
    appLinkChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "App links are unavailable.", details: nil))
        return
      }
      guard call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.appLinksReady = true
      let queued = self.pendingAppLinks
      self.pendingAppLinks.removeAll(keepingCapacity: false)
      for uri in queued {
        channel.invokeMethod("openUri", arguments: uri)
      }
      result(nil)
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

  private func registerSecureStorage(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: Self.secureStorageChannel,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard
        let values = call.arguments as? [String: Any],
        let key = values["key"] as? String,
        key == Self.secureStorageKey
      else {
        result(FlutterError(
          code: "invalid_argument",
          message: "A supported secure storage key is required.",
          details: nil
        ))
        return
      }
      switch call.method {
      case "read":
        Self.readSecureValue(key: key, result: result)
      case "write":
        guard let value = values["value"] as? String, !value.contains("\0") else {
          result(FlutterError(
            code: "invalid_argument",
            message: "A valid secure value is required.",
            details: nil
          ))
          return
        }
        Self.writeSecureValue(key: key, value: value, result: result)
      case "delete":
        Self.deleteSecureValue(key: key, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func keychainQuery(key: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: key,
    ]
  }

  private static func readSecureValue(key: String, result: @escaping FlutterResult) {
    var query = keychainQuery(key: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      result(nil)
      return
    }
    guard status == errSecSuccess,
          let data = item as? Data,
          let value = String(data: data, encoding: .utf8) else {
      result(secureStorageError(code: "read_failed"))
      return
    }
    result(value)
  }

  private static func writeSecureValue(
    key: String,
    value: String,
    result: @escaping FlutterResult
  ) {
    guard let data = value.data(using: .utf8) else {
      result(secureStorageError(code: "write_failed"))
      return
    }
    let query = keychainQuery(key: key)
    let update = [kSecValueData as String: data]
    var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      result(secureStorageError(code: "write_failed"))
      return
    }
    result(nil)
  }

  private static func deleteSecureValue(key: String, result: @escaping FlutterResult) {
    let status = SecItemDelete(keychainQuery(key: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      result(secureStorageError(code: "delete_failed"))
      return
    }
    result(nil)
  }

  private static func secureStorageError(code: String) -> FlutterError {
    return FlutterError(
      code: code,
      message: "The system credential vault operation failed.",
      details: nil
    )
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
