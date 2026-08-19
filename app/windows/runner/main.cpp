#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kInstanceMutex[] = L"Local\\com.xiaoxi.downpeed.instance";
constexpr wchar_t kRunnerWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr ULONG_PTR kAppLinkCopyDataId = 0x44504C4B;
constexpr size_t kMaxAppLinkBytes = 8192;

bool SetRegistryValue(HKEY key, const wchar_t* name,
                      const std::wstring& value) {
  return RegSetValueExW(
             key, name, 0, REG_SZ,
             reinterpret_cast<const BYTE*>(value.c_str()),
             static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t))) ==
         ERROR_SUCCESS;
}

void RegisterDownpeedUrlProtocol() {
  std::vector<wchar_t> executable(32768, L'\0');
  const DWORD length = GetModuleFileNameW(
      nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0 || static_cast<size_t>(length) >= executable.size()) {
    return;
  }
  const std::wstring executable_path(executable.data(), length);
  const std::wstring command = L"\"" + executable_path + L"\" \"%1\"";

  HKEY protocol_key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER,
                      L"Software\\Classes\\downpeed", 0, nullptr, 0,
                      KEY_SET_VALUE | KEY_CREATE_SUB_KEY, nullptr,
                      &protocol_key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  SetRegistryValue(protocol_key, nullptr, L"URL:Downpeed Protocol");
  SetRegistryValue(protocol_key, L"URL Protocol", L"");

  HKEY icon_key = nullptr;
  if (RegCreateKeyExW(protocol_key, L"DefaultIcon", 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &icon_key, nullptr) ==
      ERROR_SUCCESS) {
    SetRegistryValue(icon_key, nullptr, L"\"" + executable_path + L"\",0");
    RegCloseKey(icon_key);
  }
  HKEY command_key = nullptr;
  if (RegCreateKeyExW(protocol_key, L"shell\\open\\command", 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &command_key, nullptr) ==
      ERROR_SUCCESS) {
    SetRegistryValue(command_key, nullptr, command);
    RegCloseKey(command_key);
  }
  RegCloseKey(protocol_key);
}

std::string FindAppLink(const std::vector<std::string>& arguments) {
  for (const auto& argument : arguments) {
    if (argument.size() <= kMaxAppLinkBytes &&
        argument.rfind("downpeed://", 0) == 0) {
      return argument;
    }
  }
  return std::string();
}

HWND FindExistingWindow() {
  for (int attempt = 0; attempt < 40; ++attempt) {
    if (HWND window = FindWindowW(kRunnerWindowClass, nullptr)) {
      return window;
    }
    Sleep(50);
  }
  return nullptr;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool start_hidden =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--downpeed-startup") != command_line_arguments.end();
  const std::string app_link = FindAppLink(command_line_arguments);

  RegisterDownpeedUrlProtocol();
  HANDLE instance_mutex = CreateMutexW(nullptr, TRUE, kInstanceMutex);
  const bool already_running =
      instance_mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS;
  if (already_running) {
    if (HWND existing = FindExistingWindow()) {
      if (!app_link.empty()) {
        COPYDATASTRUCT data{};
        data.dwData = kAppLinkCopyDataId;
        data.cbData = static_cast<DWORD>(app_link.size() + 1);
        data.lpData = const_cast<char*>(app_link.c_str());
        SendMessageTimeoutW(existing, WM_COPYDATA, 0,
                            reinterpret_cast<LPARAM>(&data),
                            SMTO_ABORTIFHUNG | SMTO_BLOCK, 3000, nullptr);
      } else if (!start_hidden) {
        ShowWindow(existing, SW_RESTORE);
        SetForegroundWindow(existing);
      }
    }
    CloseHandle(instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Downpeed", origin, size)) {
    if (instance_mutex != nullptr) CloseHandle(instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex != nullptr) CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
