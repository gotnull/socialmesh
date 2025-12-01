//
//  LiveActivitiesAppAttributes.swift
//  ProtofluffWidgets
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
    
    public struct ContentState: Codable, Hashable {
        // ContentState is required by ActivityKit but we read actual data from UserDefaults
        // The live_activities package stores data there with prefixed keys
        var dummy: Int = 0
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
