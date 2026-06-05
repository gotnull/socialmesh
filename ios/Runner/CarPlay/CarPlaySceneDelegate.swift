//
//  CarPlaySceneDelegate.swift
//  Runner
//
//  CarPlay template scene for the communication surface.
//
//  PHASE 0 SPIKE: this is intentionally a static stub. Its only job right now is
//  to prove that declaring a CarPlay scene (UIApplicationSceneManifest with ONLY
//  the CPTemplateApplicationSceneSessionRoleApplication role) attaches a CarPlay
//  template UI WITHOUT disturbing the Flutter phone window, which stays on the
//  FlutterAppDelegate path because no UIWindowSceneSessionRoleApplication is
//  declared. Once verified on device, this is replaced by the real two-tab
//  browse UI driven by Dart (see CARPLAY_COMMUNICATION_V0_1.md / the in-process
//  plan).
//

import CarPlay

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let item = CPListItem(text: "SocialMesh", detailText: "CarPlay connected")
        let section = CPListSection(items: [item])
        let list = CPListTemplate(title: "SocialMesh", sections: [section])
        interfaceController.setRootTemplate(list, animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
}
