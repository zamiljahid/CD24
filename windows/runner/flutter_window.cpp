#include "flutter_window.h"
#include <optional>
#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>

#include <windows.h>
#include <psapi.h>


FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
    if (!Win32Window::OnCreate()) {
        return false;
    }

    RECT frame = GetClientArea();

    flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
            frame.right - frame.left, frame.bottom - frame.top, project_);

    if (!flutter_controller_->engine() || !flutter_controller_->view()) {
        return false;
    }

    RegisterPlugins(flutter_controller_->engine());

    // --- START OF MONITORING CODE ---
    // We get the messenger from the engine we just created
    flutter::BinaryMessenger* messenger = flutter_controller_->engine()->messenger();

    auto channel = std::make_unique<flutter::MethodChannel<>>(
            messenger, "com.hybrid.office/monitor",
            &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
            [](const flutter::MethodCall<>& call, std::unique_ptr<flutter::MethodResult<>> result) {
                if (call.method_name() == "getActiveWindow") {
                    HWND handle = GetForegroundWindow();
                    char title[256] = "";
                    GetWindowTextA(handle, title, sizeof(title));
                    result->Success(std::string(title));
                }
                else if (call.method_name() == "getIdleTime") {
                    LASTINPUTINFO lpi;
                    lpi.cbSize = sizeof(LASTINPUTINFO);
                    if (GetLastInputInfo(&lpi)) {
                        // GetTickCount64() is safer for long system uptimes
                        DWORD64 idleTime = (GetTickCount64() - lpi.dwTime) / 1000;
                        result->Success(static_cast<int>(idleTime));
                    } else {
                        result->Error("UNAVAILABLE", "Could not get idle time");
                    }
                }
                    // --- ADDED: FORCE FOCUS FOR WINDOWS ---
                else if (call.method_name() == "forceFocus") {
                    HWND hwnd = GetActiveWindow(); // Gets your Flutter window handle
                    if (hwnd) {
                        ShowWindow(hwnd, SW_RESTORE);
                        SetForegroundWindow(hwnd);
                    }
                    result->Success();
                }
                    // --- ADDED: AUDIO DETECTION FOR WINDOWS ---
                else if (call.method_name() == "isAudioPlaying") {
                    // Note: True audio detection in Windows requires COM and Core Audio APIs.
                    // For a simpler "Desktop Developer" approach, we check if the system is "busy"
                    // Most Windows systems return 0 for isAudioPlaying unless using advanced libraries.
                    // For now, we return false to avoid breaking the Dart code.
                    result->Success(false);
                }
                else {
                    result->NotImplemented();
                }
            });
    // --- END OF MONITORING CODE ---

    SetChildContent(flutter_controller_->view()->GetNativeWindow());

    flutter_controller_->engine()->SetNextFrameCallback([&]() {
        this->Show();
    });

    flutter_controller_->ForceRedraw();

    return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
