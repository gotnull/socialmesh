//
//  LiveActivitiesAppAttributes.swift
//  SocialmeshWidgets
//
//  Live Activity attributes for Meshtastic device connection status
//  NOTE: The struct MUST be named "LiveActivitiesAppAttributes" for the
//        live_activities Flutter package to work correctly.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    
    // ContentState MUST match the plugin's definition exactly:
    // The live_activities plugin (v2.4.3) expects appGroupId as non-optional String
    public struct ContentState: Codable, Hashable {
        var appGroupId: String
    }
    
    // Required by Identifiable - used for prefixed keys in UserDefaults
    var id = UUID()
}

// Extension to generate prefixed keys for UserDefaults access
extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}
