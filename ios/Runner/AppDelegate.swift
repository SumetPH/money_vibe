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
      guard call.method == "getInstallationId" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // ponytail: bundle relocation identifies installs; verify with the IPA installer in use.
      result(Bundle.main.bundleURL.resolvingSymlinksInPath().path)
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
}
