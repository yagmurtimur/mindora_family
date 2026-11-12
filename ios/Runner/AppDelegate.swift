
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }

    func didInitializeImplicitFlutterEngine(
        _ engineBridge: FlutterImplicitEngineBridge
    ) {
        GeneratedPluginRegistrant.register(
            with: engineBridge.pluginRegistry
        )

        let screenTimeChannel = FlutterMethodChannel(
            name: "mindora/screen_time",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )

        screenTimeChannel.setMethodCallHandler { call, result in

            switch call.method {

            case "ping":
                result([
                    "ok": true,
                    "platform": "ios",
                    "message": "Mindora iOS Bridge Connected"
                ])

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
