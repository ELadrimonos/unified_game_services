import Cocoa
import FlutterMacOS
import GameKit

// Presentation-only bridge. GameKit will only present its auth and dashboard
// *windows* from an NSViewController the app owns — the pure-Dart provider
// cannot do this (Apple's design, see GameCenterProvider docs). Everything else
// (sign-in state, achievements, leaderboards, scores) goes through the Dart
// provider over FFI; this channel just shows the native windows.
class MainFlutterWindow: NSWindow, GKGameCenterControllerDelegate {
  private weak var flutterVC: FlutterViewController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.flutterVC = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "game_center_example/native",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
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

    super.awakeFromNib()
  }

  private func authenticate(result: @escaping FlutterResult) {
    let local = GKLocalPlayer.local
    local.authenticateHandler = { [weak self] viewController, error in
      if let viewController = viewController {
        // GameKit needs its sign-in window presented by the host.
        self?.flutterVC?.presentAsModalWindow(viewController)
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
    flutterVC?.presentAsModalWindow(gc)
    result(true)
  }

  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    gameCenterViewController.dismiss(self)
  }
}
