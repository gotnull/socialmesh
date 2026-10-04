import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  @MainActor
  func testViewportClearsVisibleStatusBarAfterRotation() async throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }.first)
    let engine = FlutterEngine(name: "safe-area-test")
    engine.run()
    let controller = PhoneFlutterViewController(engine: engine, nibName: nil, bundle: nil)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = controller
    let originalWindow = scene.windows.first(where: { $0.isKeyWindow })
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      originalWindow?.makeKeyAndVisible()
      engine.destroyContext()
    }

    for (mask, orientation) in [
      (UIInterfaceOrientationMask.portrait, UIInterfaceOrientation.portrait),
      (.landscapeLeft, .landscapeLeft),
      (.portrait, .portrait)
    ] {
      controller.setNeedsUpdateOfSupportedInterfaceOrientations()
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
        XCTFail("Orientation request failed: \(error)")
      }
      for _ in 0..<30 {
        if scene.interfaceOrientation == orientation { break }
        try await Task.sleep(nanoseconds: 100_000_000)
      }
      XCTAssertEqual(scene.interfaceOrientation, orientation)
      controller.view.setNeedsLayout()
      controller.view.layoutIfNeeded()
      controller.viewDidLayoutSubviews()
      let initialTop = controller.additionalSafeAreaInsets.top
      controller.viewDidLayoutSubviews()
      XCTAssertEqual(controller.additionalSafeAreaInsets.top, initialTop)
      let statusBar = try XCTUnwrap(scene.statusBarManager)
      if !statusBar.isStatusBarHidden {
        let bottom = controller.view.convert(statusBar.statusBarFrame, from: nil).maxY
        XCTAssertGreaterThanOrEqual(controller.view.safeAreaInsets.top,
                                    bottom - controller.view.bounds.minY)
      }
    }
  }

}
