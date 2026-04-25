import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var deepLinkChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      deepLinkChannel = FlutterMethodChannel(
        name: "karatexchange/deeplink",
        binaryMessenger: controller.binaryMessenger
      )
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Wird aufgerufen wenn die App via URL-Scheme geöffnet wird (aus dem Widget heraus)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "karatexchange" && url.host == "converter" {
      deepLinkChannel?.invokeMethod("openConverter", arguments: nil)
    }
    return true
  }
}
