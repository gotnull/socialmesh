//
//  SocialmeshWidgetsLiveActivity.swift
//  SocialmeshWidgets
//

import ActivityKit
import WidgetKit
import SwiftUI

private var sharedDefault: UserDefaults {
    UserDefaults(suiteName: "group.com.gotnull.socialmesh") ?? UserDefaults.standard
}

// MARK: - Colors
struct AppColors {
    static let magenta = Color(red: 233/255, green: 30/255, blue: 140/255)
    static let purple = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let blue = Color(red: 79/255, green: 106/255, blue: 246/255)
    static let cyan = Color(red: 34/255, green: 211/255, blue: 238/255)
    static let green = Color(red: 52/255, green: 199/255, blue: 89/255)
    static let yellow = Color(red: 255/255, green: 159/255, blue: 10/255)
    static let red = Color(red: 255/255, green: 69/255, blue: 58/255)
    static let border = Color(red: 58/255, green: 58/255, blue: 60/255)
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
}

@available(iOS 16.2, *)
struct SocialmeshWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(AppColors.magenta)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(context: context)
                }
            } compactLeading: {
                CompactLeading(context: context)
            } compactTrailing: {
                CompactTrailing(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Compact Views

@available(iOS 16.2, *)
struct CompactLeading: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
        
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isConnected ? AppColors.green : AppColors.red)
    }
}

@available(iOS 16.2, *)
struct CompactTrailing: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        let battery = sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
        let isCharging = battery > 100
        
        HStack(spacing: 4) {
            Text("\(nodes)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.green)
            
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.green)
            }
        }
    }
}

@available(iOS 16.2, *)
struct MinimalView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        
        Text("\(nodes)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(AppColors.green)
    }
}

// MARK: - Expanded Views

@available(iOS 16.2, *)
struct ExpandedLeading: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let shortName = sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????"
        let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
        
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? AppColors.green : AppColors.red)
                .frame(width: 8, height: 8)
            Text(shortName)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedTrailing: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let battery = sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
        let isCharging = battery > 100
        let displayLevel = min(battery, 100)
        
        HStack(spacing: 4) {
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.green)
            }
            
            BatteryRing(level: displayLevel, size: 28)
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedCenter: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let deviceName = sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic"
        
        Text(deviceName)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
    }
}

@available(iOS 16.2, *)
struct ExpandedBottom: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        let total = sharedDefault.integer(forKey: context.attributes.prefixedKey("totalNodes"))
        let channel = sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization"))
        let signal = sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength"))
        
        HStack(spacing: 20) {
            // Nodes
            VStack(spacing: 2) {
                Text("\(nodes)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.green)
                Text(total > 0 ? "of \(total)" : "nodes")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            // Channel
            VStack(spacing: 2) {
                Text(String(format: "%.0f", channel))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("CH%")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            // Signal
            VStack(spacing: 2) {
                Text("\(signal)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("dBm")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var deviceName: String { sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic" }
    var shortName: String { sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????" }
    var isConnected: Bool { sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected")) }
    var battery: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel")) }
    var signal: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength")) }
    var channel: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization")) }
    var airtime: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("airtime")) }
    var nodes: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline")) }
    var totalNodes: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("totalNodes")) }
    var tx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("sentPackets")) }
    var rx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("receivedPackets")) }
    var snr: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("snr")) }
    
    var isCharging: Bool { battery > 100 }
    var displayBattery: Int { min(battery, 100) }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left - Device info
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? AppColors.green : AppColors.red)
                        .frame(width: 10, height: 10)
                    
                    Text(shortName)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(deviceName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                // Signal bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("SIGNAL")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(signal) dBm")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("SNR \(snr)")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    SignalBar(strength: signal)
                }
                
                // CH / AIR row
                HStack(spacing: 16) {
                    ProgressItem(label: "CH", value: channel, color: AppColors.purple)
                    ProgressItem(label: "AIR", value: airtime, color: AppColors.blue)
                }
                
                // TX/RX
                HStack(spacing: 16) {
                    Label("\(tx)", systemImage: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.magenta)
                    
                    Label("\(rx)", systemImage: "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.green)
                }
            }
            
            // Right - Battery & Nodes
            VStack(spacing: 8) {
                BatteryRing(level: displayBattery, size: 52)
                
                if isCharging {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("CHG")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.green)
                }
                
                Text("\(nodes)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.green)
                
                Text("online")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(width: 70)
        }
        .padding(16)
    }
}

// MARK: - Components

struct BatteryRing: View {
    let level: Int
    let size: CGFloat
    
    var color: Color {
        if level <= 20 { return AppColors.red }
        if level <= 50 { return AppColors.yellow }
        return AppColors.green
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.border, lineWidth: size * 0.1)
            
            Circle()
                .trim(from: 0, to: CGFloat(level) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(level)")
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

struct SignalBar: View {
    let strength: Int
    
    var percent: CGFloat {
        let normalized = CGFloat(max(-120, min(-30, strength)) + 120) / 90
        return normalized
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.border.opacity(0.5))
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.magenta, AppColors.purple, AppColors.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * percent)
            }
        }
        .frame(height: 6)
    }
}

struct ProgressItem: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.border.opacity(0.5))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(value, 100) / 100))
                }
            }
            .frame(height: 4)
        }
    }
}
