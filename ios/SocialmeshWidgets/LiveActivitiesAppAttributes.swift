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
    
    public struct ContentState: Codable, Hashable {
        // The live_activities plugin passes appGroupId when creating the activity
        // We store it but read actual data from UserDefaults with prefixed keys
        var appGroupId: String?
        
        init(appGroupId: String? = nil) {
            self.appGroupId = appGroupId
        }
    }
    
    // Required by Identifiable - used for prefixed keys in UserDefaults
    var id = UUID()
    
    init(id: UUID = UUID()) {
        self.id = id
    }
}

// Extension to generate prefixed keys for UserDefaults access
extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}
