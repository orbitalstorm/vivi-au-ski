import CoreMotion
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  private let accelerometerChannelName = "cloud.orbital8.vivi_au_ski/accelerometer"
  private let deviceChannelName = "cloud.orbital8.vivi_au_ski/device"
  private let motionManager = CMMotionManager()
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let eventChannel = FlutterEventChannel(
      name: accelerometerChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(self)

    let methodChannel = FlutterMethodChannel(
      name: deviceChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate released", details: nil))
        return
      }
      switch call.method {
      case "hasAccelerometer":
        result(self.motionManager.isAccelerometerAvailable)
      case "getDeviceInfo":
        let device = UIDevice.current
        result([
          "platform": "ios",
          "model": device.model,
          "systemName": device.systemName,
          "systemVersion": device.systemVersion,
          "hasAccelerometer": self.motionManager.isAccelerometerAvailable
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    guard motionManager.isAccelerometerAvailable else {
      return nil
    }
    motionManager.accelerometerUpdateInterval = 1.0 / 60.0
    motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
      guard let acceleration = data?.acceleration else { return }
      // Convert CoreMotion g-units into m/s^2 matching Android Sensor.TYPE_ACCELEROMETER portrait convention:
      // Tilting iPhone right gives positive acceleration.x in CoreMotion -> negative ax in Android convention.
      let gravity = 9.80665
      let ax = -acceleration.x * gravity
      let ay = -acceleration.y * gravity
      let az = -acceleration.z * gravity
      self?.eventSink?([
        "x": ax,
        "y": ay,
        "z": az
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionManager.stopAccelerometerUpdates()
    eventSink = nil
    return nil
  }
}
