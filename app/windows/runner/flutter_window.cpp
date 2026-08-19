#include "flutter_window.h"

#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <wincred.h>

#include <optional>
#include <string>
#include <utility>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {

constexpr char kDesktopActionsChannel[] =
    "com.xiaoxi.downpeed/desktop_actions";
constexpr char kSecureStorageChannel[] =
    "com.xiaoxi.downpeed/secure_storage";
constexpr char kAppLinksChannel[] = "com.xiaoxi.downpeed/app_links";
constexpr char kSecureStorageKey[] = "proxy-password";
constexpr wchar_t kProxyCredentialTarget[] = L"Downpeed/proxy-password";
constexpr UINT_PTR kCompletionNotificationTimer = 0xD0A1;
constexpr ULONG_PTR kAppLinkCopyDataId = 0x44504C4B;
constexpr size_t kMaxAppLinkBytes = 8192;

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty() || value.find('\0') != std::string::npos) {
    return std::wstring();
  }
  const int target_length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0);
  if (target_length <= 0) {
    return std::wstring();
  }
  std::wstring converted(target_length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), converted.data(),
                          target_length) == 0) {
    return std::wstring();
  }
  return converted;
}

const std::string* StringArgument(const flutter::EncodableValue* arguments,
                                  const char* name) {
  if (arguments == nullptr) {
    return nullptr;
  }
  const auto* values = std::get_if<flutter::EncodableMap>(arguments);
  if (values == nullptr) {
    return nullptr;
  }
  const auto iterator = values->find(flutter::EncodableValue(name));
  if (iterator == values->end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&iterator->second);
}

bool CompletedFileExists(const std::wstring& path) {
  if (path.empty() || PathIsRelativeW(path.c_str())) {
    return false;
  }
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             bool start_hidden)
    : project_(project), start_hidden_(start_hidden) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  desktop_actions_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kDesktopActionsChannel,
          &flutter::StandardMethodCodec::GetInstance());
  desktop_actions_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleDesktopAction(call, std::move(result));
      });
  secure_storage_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kSecureStorageChannel,
          &flutter::StandardMethodCodec::GetInstance());
  secure_storage_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleSecureStorage(call, std::move(result));
      });
  app_links_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kAppLinksChannel,
          &flutter::StandardMethodCodec::GetInstance());
  app_links_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "ready") {
          result->NotImplemented();
          return;
        }
        app_links_ready_ = true;
        const auto queued = std::move(pending_app_links_);
        pending_app_links_.clear();
        for (const auto& uri : queued) {
          DispatchAppLink(uri);
        }
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (!start_hidden_) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  ClearCompletionNotification();
  desktop_actions_channel_.reset();
  secure_storage_channel_.reset();
  app_links_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleSecureStorage(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string* key = StringArgument(method_call.arguments(), "key");
  if (key == nullptr || *key != kSecureStorageKey) {
    result->Error("invalid_argument",
                  "A supported secure storage key is required.");
    return;
  }

  if (method_call.method_name() == "read") {
    PCREDENTIALW credential = nullptr;
    if (!CredReadW(kProxyCredentialTarget, CRED_TYPE_GENERIC, 0,
                   &credential)) {
      if (GetLastError() == ERROR_NOT_FOUND) {
        result->Success();
      } else {
        result->Error("read_failed",
                      "The system credential vault operation failed.");
      }
      return;
    }
    std::string value;
    if (credential->CredentialBlobSize > 0 &&
        credential->CredentialBlob != nullptr) {
      value.assign(
          reinterpret_cast<const char*>(credential->CredentialBlob),
          credential->CredentialBlobSize);
    }
    CredFree(credential);
    result->Success(flutter::EncodableValue(value));
    return;
  }

  if (method_call.method_name() == "write") {
    const std::string* value =
        StringArgument(method_call.arguments(), "value");
    if (value == nullptr || value->find('\0') != std::string::npos) {
      result->Error("invalid_argument", "A valid secure value is required.");
      return;
    }
    CREDENTIALW credential{};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = const_cast<LPWSTR>(kProxyCredentialTarget);
    credential.CredentialBlobSize = static_cast<DWORD>(value->size());
    credential.CredentialBlob = reinterpret_cast<LPBYTE>(
        const_cast<char*>(value->data()));
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    credential.UserName = const_cast<LPWSTR>(L"Downpeed");
    if (!CredWriteW(&credential, 0)) {
      result->Error("write_failed",
                    "The system credential vault operation failed.");
      return;
    }
    result->Success();
    return;
  }

  if (method_call.method_name() == "delete") {
    if (!CredDeleteW(kProxyCredentialTarget, CRED_TYPE_GENERIC, 0) &&
        GetLastError() != ERROR_NOT_FOUND) {
      result->Error("delete_failed",
                    "The system credential vault operation failed.");
      return;
    }
    result->Success();
    return;
  }

  result->NotImplemented();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_COPYDATA) {
    const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (data == nullptr || data->dwData != kAppLinkCopyDataId ||
        data->lpData == nullptr || data->cbData < 2 ||
        static_cast<size_t>(data->cbData) > kMaxAppLinkBytes + 1) {
      return FALSE;
    }
    const auto* bytes = static_cast<const char*>(data->lpData);
    if (bytes[data->cbData - 1] != '\0') {
      return FALSE;
    }
    std::string uri(bytes, bytes + data->cbData - 1);
    if (uri.find('\0') != std::string::npos ||
        uri.rfind("downpeed://", 0) != 0) {
      return FALSE;
    }
    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
    DispatchAppLink(uri);
    return TRUE;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_TIMER:
      if (wparam == kCompletionNotificationTimer) {
        KillTimer(hwnd, kCompletionNotificationTimer);
        ClearCompletionNotification();
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::DispatchAppLink(const std::string& uri) {
  if (!app_links_ready_ || app_links_channel_ == nullptr) {
    pending_app_links_.push_back(uri);
    return;
  }
  app_links_channel_->InvokeMethod(
      "openUri", std::make_unique<flutter::EncodableValue>(uri));
}

void FlutterWindow::HandleDesktopAction(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "showCompletionNotification") {
    const std::string* title_value =
        StringArgument(method_call.arguments(), "title");
    const std::string* body_value =
        StringArgument(method_call.arguments(), "body");
    const std::wstring title =
        title_value == nullptr ? std::wstring() : Utf16FromUtf8(*title_value);
    const std::wstring body =
        body_value == nullptr ? std::wstring() : Utf16FromUtf8(*body_value);
    if (title.empty() || body.empty()) {
      result->Error("invalid_argument", "Notification text is required.");
      return;
    }
    if (!ShowCompletionNotification(title, body)) {
      result->Error("notification_unavailable",
                    "The completion notification could not be delivered.");
      return;
    }
    result->Success();
    return;
  }

  if (method_call.method_name() != "openFile" &&
      method_call.method_name() != "revealFile") {
    result->NotImplemented();
    return;
  }
  const std::string* path_value =
      StringArgument(method_call.arguments(), "path");
  const std::wstring path =
      path_value == nullptr ? std::wstring() : Utf16FromUtf8(*path_value);
  if (path.empty() || PathIsRelativeW(path.c_str())) {
    result->Error("invalid_argument", "An absolute file path is required.");
    return;
  }
  if (!CompletedFileExists(path)) {
    result->Error("file_not_found", "The completed file no longer exists.");
    return;
  }

  if (method_call.method_name() == "openFile") {
    const auto opened = reinterpret_cast<INT_PTR>(
        ShellExecuteW(GetHandle(), L"open", path.c_str(), nullptr, nullptr,
                      SW_SHOWNORMAL));
    if (opened <= 32) {
      result->Error("open_failed",
                    "The system could not open the completed file.");
      return;
    }
    result->Success();
    return;
  }

  PIDLIST_ABSOLUTE item = nullptr;
  const HRESULT parsed =
      SHParseDisplayName(path.c_str(), nullptr, &item, 0, nullptr);
  if (FAILED(parsed) || item == nullptr) {
    result->Error("open_failed",
                  "The system could not locate the completed file.");
    return;
  }
  const HRESULT revealed = SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
  CoTaskMemFree(item);
  if (FAILED(revealed)) {
    result->Error("open_failed",
                  "The file manager could not reveal the completed file.");
    return;
  }
  result->Success();
}

bool FlutterWindow::ShowCompletionNotification(const std::wstring& title,
                                               const std::wstring& body) {
  ClearCompletionNotification();
  completion_notification_ = {};
  completion_notification_.cbSize = sizeof(NOTIFYICONDATAW);
  completion_notification_.hWnd = GetHandle();
  completion_notification_.uID = 1;
  completion_notification_.uFlags =
      NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_INFO;
  completion_notification_.uCallbackMessage = WM_APP + 1;
  completion_notification_.hIcon = static_cast<HICON>(LoadImageW(
      GetModuleHandle(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON, 0,
      0, LR_DEFAULTSIZE | LR_SHARED));
  wcscpy_s(completion_notification_.szTip, L"Downpeed");
  wcsncpy_s(completion_notification_.szInfoTitle, title.c_str(), _TRUNCATE);
  wcsncpy_s(completion_notification_.szInfo, body.c_str(), _TRUNCATE);
  completion_notification_.dwInfoFlags = NIIF_INFO;
  if (!Shell_NotifyIconW(NIM_ADD, &completion_notification_)) {
    completion_notification_ = {};
    return false;
  }
  completion_notification_active_ = true;
  completion_notification_.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &completion_notification_);
  SetTimer(GetHandle(), kCompletionNotificationTimer, 8000, nullptr);
  return true;
}

void FlutterWindow::ClearCompletionNotification() {
  if (!completion_notification_active_) {
    return;
  }
  Shell_NotifyIconW(NIM_DELETE, &completion_notification_);
  completion_notification_active_ = false;
  completion_notification_ = {};
}
