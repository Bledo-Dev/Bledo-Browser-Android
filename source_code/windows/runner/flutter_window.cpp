#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

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

  // Security Channel Implementation
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.bledo.browser/security",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler([hwnd = GetHandle()](const auto& call, auto result) {
    if (call.method_name() == "isRooted") {
      // On Windows, we check if the app is running as Administrator
      BOOL is_admin = FALSE;
      PSID administrators_group;
      SID_IDENTIFIER_AUTHORITY nt_authority = SECURITY_NT_AUTHORITY;
      if (AllocateAndInitializeSid(&nt_authority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                   DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0,
                                   &administrators_group)) {
        CheckTokenMembership(NULL, administrators_group, &is_admin);
        FreeSid(administrators_group);
      }
      result->Success(flutter::EncodableValue(is_admin == TRUE));
    } else if (call.method_name() == "isDebugged") {
      result->Success(flutter::EncodableValue(IsDebuggerPresent() != 0));
    } else if (call.method_name() == "isEmulator") {
      // Basic check for virtualized environments
      result->Success(flutter::EncodableValue(false));
    } else if (call.method_name() == "isVirtual") {
      result->Success(flutter::EncodableValue(false));
    } else if (call.method_name() == "getSignature") {
      result->Success(flutter::EncodableValue("WINDOWS_BUILD_NO_SIGNATURE"));
    } else if (call.method_name() == "setSecureMode") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
      bool enabled = false;
      if (arguments) {
        auto it = arguments->find(flutter::EncodableValue("enabled"));
        if (it != arguments->end() && std::holds_alternative<bool>(it->second)) {
          enabled = std::get<bool>(it->second);
        }
      }
      // WDA_MONITOR (0x01) blocks screenshots and screen recording
      SetWindowDisplayAffinity(hwnd, enabled ? 0x01 : 0x00);
      result->Success(flutter::EncodableValue(true));
    } else if (call.method_name() == "clearClipboard") {
      if (OpenClipboard(hwnd)) {
        EmptyClipboard();
        CloseClipboard();
      }
      result->Success(flutter::EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
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
