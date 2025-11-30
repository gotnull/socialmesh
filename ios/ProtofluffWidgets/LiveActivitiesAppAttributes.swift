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

struct LiveActivitiesAppAttributes: ActivityAttributes {
    public typealias MeshActivityStatus = ContentState
    
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties - passed from Flutter via UserDefaults
        var deviceName: String
        var shortName: String
        var batteryLevel: Int
        var signalStrength: Int
        var nodesOnline: Int
        var channelUtilization: Double
        var airtime: Double
        var sentPackets: Int
        var receivedPackets: Int
        var lastUpdated: Int
        var isConnected: Bool
    }
    
    // Fixed non-changing properties
    var nodeNum: Int
}
