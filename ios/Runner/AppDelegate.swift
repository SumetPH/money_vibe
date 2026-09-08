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
  }
}
