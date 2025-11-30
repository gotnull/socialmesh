//
//  ProtofluffWidgetsLiveActivity.swift
//  ProtofluffWidgets
//
//  Live Activity widget for Meshtastic device connection status
//  Uses live_activities Flutter package for data communication via App Groups
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct ProtofluffWidgetsLiveActivity: Widget {
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
                        Text(context.state.shortName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        BatteryView(level: context.state.batteryLevel)
                        SignalView(strength: context.state.signalStrength)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.deviceName)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ch. Util: \(String(format: "%.1f", context.state.channelUtilization))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Airtime: \(String(format: "%.1f", context.state.airtime))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("TX: \(context.state.sentPackets)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("RX: \(context.state.receivedPackets)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                Text("\(context.state.nodesOnline)")
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
                HStack(spacing: 4) {
                    Image(systemName: context.state.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(context.state.isConnected ? .green : .red)
                }
            } compactTrailing: {
                // Compact trailing - show battery
                BatteryView(level: context.state.batteryLevel, compact: true)
            } minimal: {
                // Minimal - just show connection indicator
                Image(systemName: context.state.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(context.state.isConnected ? .green : .red)
            }
            .widgetURL(URL(string: "protofluff://connect"))
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Connection status icon
            VStack {
                Image(systemName: context.state.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
                    .foregroundColor(context.state.isConnected ? .green : .red)
            }
            .frame(width: 44)
            
            // Center: Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.deviceName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    // Channel utilization
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", context.state.channelUtilization))%")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    // Nodes online
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(context.state.nodesOnline)")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                    
                    // Packets
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                        Text("\(context.state.sentPackets)/\(context.state.receivedPackets)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Right: Battery and signal
            VStack(alignment: .trailing, spacing: 4) {
                BatteryView(level: context.state.batteryLevel)
                SignalView(strength: context.state.signalStrength)
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

// MARK: - Preview

@available(iOS 16.2, *)
struct ProtofluffWidgetsLiveActivity_Previews: PreviewProvider {
    static let attributes = LiveActivitiesAppAttributes(nodeNum: 123456789)
    static let state = LiveActivitiesAppAttributes.ContentState(
        deviceName: "Meshtastic_29A9",
        shortName: "29A9",
        batteryLevel: 85,
        signalStrength: -55,
        nodesOnline: 12,
        channelUtilization: 2.5,
        airtime: 1.2,
        sentPackets: 156,
        receivedPackets: 234,
        lastUpdated: Int(Date().timeIntervalSince1970 * 1000),
        isConnected: true
    )
    
    static var previews: some View {
        attributes
            .previewContext(state, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")
        
        attributes
            .previewContext(state, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")
        
        attributes
            .previewContext(state, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")
        
        attributes
            .previewContext(state, viewKind: .content)
            .previewDisplayName("Lock Screen")
    }
}
