#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project,
                         bool start_hidden = false);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void HandleDesktopAction(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleSecureStorage(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DispatchAppLink(const std::string& uri);
  bool ShowCompletionNotification(const std::wstring& title,
                                  const std::wstring& body);
  void ClearCompletionNotification();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_actions_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      secure_storage_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      app_links_channel_;
  std::vector<std::string> pending_app_links_;
  NOTIFYICONDATAW completion_notification_{};
  bool completion_notification_active_ = false;
  bool start_hidden_ = false;
  bool app_links_ready_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
