import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let installationChannel = FlutterMethodChannel(
      name: "money_vibe/installation",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    installationChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInstallationId":
        // ponytail: bundle relocation identifies installs; verify with the IPA installer in use.
        result(Bundle.main.bundleURL.resolvingSymlinksInPath().path)
      case "clearAppIconBadge":
        self.clearAppIconBadge(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let appIconChannel = FlutterMethodChannel(
      name: "money_vibe/app_icon",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    appIconChannel.setMethodCallHandler { call, result in
      guard call.method == "setDarkIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // primary icon = AppIconDark, alternate "AppIcon" = light
      let isDark = call.arguments as? Bool ?? true
      let target: String? = isDark ? nil : "AppIcon"
      let app = UIApplication.shared
      guard app.supportsAlternateIcons, app.alternateIconName != target else {
        result(nil)
        return
      }
      app.setAlternateIconName(target) { error in
        if let error = error {
          result(FlutterError(code: "set_icon_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  private func clearAppIconBadge(result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else {
      UIApplication.shared.applicationIconBadgeNumber = 0
      result(nil)
      return
    }
    UNUserNotificationCenter.current().setBadgeCount(0) { error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "clear_badge_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }
}
