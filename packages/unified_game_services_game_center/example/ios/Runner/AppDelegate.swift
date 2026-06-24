import Flutter
import UIKit
import GameKit

// Presentation-only bridge — see macos/Runner/MainFlutterWindow.swift for the
// rationale. GameKit presents its auth + dashboard windows from a
// UIViewController the app owns; the Dart provider drives everything else.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, GKGameCenterControllerDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "game_center_example/native",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "GameCenterBridge")!.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "authenticate":
        self?.authenticate(result: result)
      case "showDashboard":
        self?.showDashboard(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private var rootVC: UIViewController? {
    return window?.rootViewController
  }

  private func authenticate(result: @escaping FlutterResult) {
    let local = GKLocalPlayer.local
    local.authenticateHandler = { [weak self] viewController, error in
      if let viewController = viewController {
        self?.rootVC?.present(viewController, animated: true)
        return
      }
      if let error = error {
        result(FlutterError(code: "auth_failed", message: error.localizedDescription, details: nil))
        return
      }
      result(local.isAuthenticated)
    }
  }

  private func showDashboard(result: @escaping FlutterResult) {
    guard GKLocalPlayer.local.isAuthenticated else {
      result(FlutterError(code: "not_authenticated", message: "Authenticate first.", details: nil))
      return
    }
    let gc = GKGameCenterViewController(state: .dashboard)
    gc.gameCenterDelegate = self
    rootVC?.present(gc, animated: true)
    result(true)
  }

  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    gameCenterViewController.dismiss(animated: true)
  }
}
