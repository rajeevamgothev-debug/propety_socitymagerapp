import Flutter
import FirebaseMessaging
import UIKit
import GoogleMaps
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let googleMapsApiKey = "AIzaSyBd4He3yQcnMKV3qgMmdApz16tB_f7Buhs"
  private var configChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey(googleMapsApiKey)
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    NSLog("iOSPushDebug: didRegisterForRemoteNotificationsWithDeviceToken apnsToken=\(token)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("iOSPushDebug: didFailToRegisterForRemoteNotificationsWithError error=\(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configChannel = FlutterMethodChannel(
      name: "urban_easy_property_flutter_app/config",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    configChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "googleMapsApiKey":
        result(self?.googleMapsApiKey ?? "")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
