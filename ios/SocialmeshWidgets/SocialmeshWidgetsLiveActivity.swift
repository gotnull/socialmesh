//
//  SocialmeshWidgetsLiveActivity.swift
//  SocialmeshWidgets
//
//  Live Activity widget for Meshtastic device connection status
//  Uses live_activities Flutter package for data communication via App Groups
//

import ActivityKit
import WidgetKit
import SwiftUI

// Shared UserDefaults for reading Flutter data
let sharedDefault = UserDefaults(suiteName: "group.socialmesh.liveactivities")!

@available(iOS 16.2, *)
struct SocialmeshWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                        Text(sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        BatteryView(level: sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel")))
                        SignalView(strength: sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength")))
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic")
                        .font(.headline)
                        .lineLimit(1)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    let channelUtil = sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization"))
                    let airtime = sharedDefault.double(forKey: context.attributes.prefixedKey("airtime"))
                    let sentPackets = sharedDefault.integer(forKey: context.attributes.prefixedKey("sentPackets"))
                    let receivedPackets = sharedDefault.integer(forKey: context.attributes.prefixedKey("receivedPackets"))
                    let nodesOnline = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ch. Util: \(String(format: "%.1f", channelUtil))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Airtime: \(String(format: "%.1f", airtime))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("TX: \(sentPackets)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("RX: \(receivedPackets)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                Text("\(nodesOnline)")
                                    .font(.caption2)
                            }
                            .foregroundColor(.green)
                            Text("online")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                // Compact leading - show connection status
                let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
                HStack(spacing: 4) {
                    Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(isConnected ? .green : .red)
                }
            } compactTrailing: {
                // Compact trailing - show battery
                BatteryView(level: sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel")), compact: true)
            } minimal: {
                // Minimal - just show connection indicator
                let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
                Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(isConnected ? .green : .red)
            }
            .widgetURL(URL(string: "socialmesh://connect"))
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var deviceName: String {
        sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic"
    }
    
    var isConnected: Bool {
        sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
    }
    
    var batteryLevel: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
    }
    
    var signalStrength: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength"))
    }
    
    var channelUtilization: Double {
        sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization"))
    }
    
    var nodesOnline: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
    }
    
    var sentPackets: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("sentPackets"))
    }
    
    var receivedPackets: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("receivedPackets"))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Connection status icon
            VStack {
                Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
                    .foregroundColor(isConnected ? .green : .red)
            }
            .frame(width: 44)
            
            // Center: Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(deviceName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    // Channel utilization
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", channelUtilization))%")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    // Nodes online
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(nodesOnline)")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                    
                    // Packets
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                        Text("\(sentPackets)/\(receivedPackets)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Right: Battery and signal
            VStack(alignment: .trailing, spacing: 4) {
                BatteryView(level: batteryLevel)
                SignalView(strength: signalStrength)
            }
        }
        .padding()
    }
}

// MARK: - Battery View

struct BatteryView: View {
    let level: Int
    var compact: Bool = false
    
    var batteryColor: Color {
        if level <= 20 {
            return .red
        } else if level <= 50 {
            return .orange
        } else {
            return .green
        }
    }
    
    var batteryIcon: String {
        if level <= 25 {
            return "battery.25"
        } else if level <= 50 {
            return "battery.50"
        } else if level <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)
            if !compact {
                Text("\(level)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Signal View

struct SignalView: View {
    let strength: Int
    
    var signalBars: Int {
        if strength >= -50 {
            return 4
        } else if strength >= -60 {
            return 3
        } else if strength >= -70 {
            return 2
        } else if strength >= -80 {
            return 1
        } else {
            return 0
        }
    }
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < signalBars ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + index * 3))
            }
        }
    }
}
