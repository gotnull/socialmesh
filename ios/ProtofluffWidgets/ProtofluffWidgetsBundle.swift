//
//  ProtofluffWidgetsBundle.swift
//  ProtofluffWidgets
//
//  Widget bundle for Protofluff widgets and Live Activities
//

import WidgetKit
import SwiftUI

@main
struct ProtofluffWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            ProtofluffWidgetsLiveActivity()
        }
    }
}
