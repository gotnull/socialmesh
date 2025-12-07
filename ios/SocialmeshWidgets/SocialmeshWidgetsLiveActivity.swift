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
private var sharedDefault: UserDefaults {
    UserDefaults(suiteName: "group.com.gotnull.socialmesh") ?? UserDefaults.standard
}

// MARK: - App Theme Colors (matching Flutter app)
struct AppColors {
    // Brand gradient colors
    static let magenta = Color(red: 233/255, green: 30/255, blue: 140/255)   // #E91E8C
    static let purple = Color(red: 139/255, green: 92/255, blue: 246/255)    // #8B5CF6
    static let blue = Color(red: 79/255, green: 106/255, blue: 246/255)      // #4F6AF6
    
    // Background colors
    static let darkBackground = Color(red: 31/255, green: 38/255, blue: 51/255)  // #1F2633
    static let darkSurface = Color(red: 41/255, green: 48/255, blue: 61/255)     // #29303D
    static let darkBorder = Color(red: 65/255, green: 74/255, blue: 90/255)      // #414A5A
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 209/255, green: 213/255, blue: 219/255)  // #D1D5DB
    static let textTertiary = Color(red: 156/255, green: 163/255, blue: 175/255)   // #9CA3AF
    
    // Status colors
    static let successGreen = Color(red: 74/255, green: 222/255, blue: 128/255)    // #4ADE80
    static let warningYellow = Color(red: 251/255, green: 191/255, blue: 36/255)   // #FBBF24
    static let errorRed = Color(red: 239/255, green: 68/255, blue: 68/255)         // #EF4444
    
    // Brand gradient
    static let brandGradient = LinearGradient(
        colors: [magenta, purple, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let subtleGradient = LinearGradient(
        colors: [magenta.opacity(0.3), purple.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

@available(iOS 16.2, *)
struct SocialmeshWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(AppColors.darkBackground)
                .activitySystemActionForegroundColor(AppColors.magenta)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            .widgetURL(URL(string: "socialmesh://connect"))
        }
    }
}

// MARK: - Dynamic Island Expanded Views

@available(iOS 16.2, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
        
        HStack(spacing: 6) {
            // Animated radio icon with gradient
            Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isConnected ? AppColors.brandGradient : LinearGradient(colors: [AppColors.errorRed], startPoint: .leading, endPoint: .trailing))
            
            Text(sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let batteryLevel = sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
        
        HStack(spacing: 6) {
            BatteryIndicator(level: batteryLevel, showPercentage: true)
            SignalBars(strength: sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength")))
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        Text(sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
    }
}

@available(iOS 16.2, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let channelUtil = sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization"))
        let airtime = sharedDefault.double(forKey: context.attributes.prefixedKey("airtime"))
        let sentPackets = sharedDefault.integer(forKey: context.attributes.prefixedKey("sentPackets"))
        let receivedPackets = sharedDefault.integer(forKey: context.attributes.prefixedKey("receivedPackets"))
        let nodesOnline = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        
        HStack(spacing: 0) {
            // Channel Utilization
            StatPill(icon: "waveform.path", value: String(format: "%.1f%%", channelUtil), color: AppColors.purple)
            
            Spacer()
            
            // Nodes Online
            StatPill(icon: "person.2.fill", value: "\(nodesOnline)", color: AppColors.successGreen)
            
            Spacer()
            
            // TX/RX
            StatPill(icon: "arrow.up.arrow.down", value: "\(sentPackets)/\(receivedPackets)", color: AppColors.blue)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Compact Views

@available(iOS 16.2, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
        
        Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isConnected ? AppColors.brandGradient : LinearGradient(colors: [AppColors.errorRed], startPoint: .leading, endPoint: .trailing))
    }
}

@available(iOS 16.2, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let batteryLevel = sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
        
        HStack(spacing: 3) {
            BatteryIndicator(level: batteryLevel, showPercentage: false, compact: true)
            Text("\(batteryLevel)%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(batteryColor(for: batteryLevel))
        }
    }
    
    func batteryColor(for level: Int) -> Color {
        if level <= 20 { return AppColors.errorRed }
        if level <= 50 { return AppColors.warningYellow }
        return AppColors.successGreen
    }
}

@available(iOS 16.2, *)
struct MinimalView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
        
        Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isConnected ? AppColors.brandGradient : LinearGradient(colors: [AppColors.errorRed], startPoint: .leading, endPoint: .trailing))
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var deviceName: String {
        sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic"
    }
    
    var shortName: String {
        sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????"
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
    
    var airtime: Double {
        sharedDefault.double(forKey: context.attributes.prefixedKey("airtime"))
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
        VStack(spacing: 12) {
            // Top row: Icon + Short Name | Device Name | Battery + Signal
            HStack(alignment: .center) {
                // Left: Connection icon with short name
                HStack(spacing: 8) {
                    ZStack {
                        // Gradient glow effect
                        Circle()
                            .fill(AppColors.subtleGradient)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isConnected ? AppColors.brandGradient : LinearGradient(colors: [AppColors.errorRed], startPoint: .leading, endPoint: .trailing))
                    }
                    
                    Text(shortName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                // Center: Device name
                Text(deviceName)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Right: Battery and signal
                HStack(spacing: 8) {
                    BatteryIndicator(level: batteryLevel, showPercentage: true)
                    SignalBars(strength: signalStrength)
                }
            }
            
            // Divider with gradient
            Rectangle()
                .fill(AppColors.darkBorder)
                .frame(height: 1)
            
            // Bottom row: Stats
            HStack(spacing: 16) {
                // Channel Utilization
                StatItem(
                    icon: "waveform.path",
                    label: "Ch. Util",
                    value: String(format: "%.1f%%", channelUtilization),
                    color: AppColors.purple
                )
                
                Spacer()
                
                // Airtime
                StatItem(
                    icon: "clock.fill",
                    label: "Airtime",
                    value: String(format: "%.1f%%", airtime),
                    color: AppColors.blue
                )
                
                Spacer()
                
                // TX/RX
                StatItem(
                    icon: "arrow.up.arrow.down",
                    label: "TX/RX",
                    value: "\(sentPackets)/\(receivedPackets)",
                    color: AppColors.magenta
                )
                
                Spacer()
                
                // Nodes online
                StatItem(
                    icon: "person.2.fill",
                    label: "Online",
                    value: "\(nodesOnline)",
                    color: AppColors.successGreen
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Reusable Components

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

struct BatteryIndicator: View {
    let level: Int
    var showPercentage: Bool = true
    var compact: Bool = false
    
    var batteryColor: Color {
        if level <= 20 { return AppColors.errorRed }
        if level <= 50 { return AppColors.warningYellow }
        return AppColors.successGreen
    }
    
    var batteryIcon: String {
        if level <= 10 { return "battery.0" }
        if level <= 25 { return "battery.25" }
        if level <= 50 { return "battery.50" }
        if level <= 75 { return "battery.75" }
        return "battery.100"
    }
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: batteryIcon)
                .font(.system(size: compact ? 14 : 16, weight: .medium))
                .foregroundColor(batteryColor)
            
            if showPercentage {
                Text("\(level)%")
                    .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(batteryColor)
            }
        }
    }
}

struct SignalBars: View {
    let strength: Int
    
    var signalBars: Int {
        if strength >= -50 { return 4 }
        if strength >= -70 { return 3 }
        if strength >= -85 { return 2 }
        if strength >= -100 { return 1 }
        return 0
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < signalBars ? AppColors.successGreen : AppColors.darkBorder)
                    .frame(width: 3, height: CGFloat(5 + index * 3))
            }
        }
    }
}
