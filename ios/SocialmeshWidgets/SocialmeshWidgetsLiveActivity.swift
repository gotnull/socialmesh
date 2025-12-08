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
    static let darkBackground = Color(red: 18/255, green: 18/255, blue: 18/255)   // True black for OLED
    static let darkCard = Color(red: 28/255, green: 28/255, blue: 30/255)         // Card background
    static let darkSurface = Color(red: 41/255, green: 48/255, blue: 61/255)      // #29303D
    static let darkBorder = Color(red: 58/255, green: 58/255, blue: 60/255)       // Subtle border
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 174/255, green: 174/255, blue: 178/255)  // iOS secondary
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)     // iOS tertiary
    
    // Status colors
    static let successGreen = Color(red: 52/255, green: 199/255, blue: 89/255)     // iOS green
    static let warningYellow = Color(red: 255/255, green: 159/255, blue: 10/255)   // iOS orange
    static let errorRed = Color(red: 255/255, green: 69/255, blue: 58/255)         // iOS red
    
    // Brand gradient
    static let brandGradient = LinearGradient(
        colors: [magenta, purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let subtleGradient = LinearGradient(
        colors: [magenta.opacity(0.15), purple.opacity(0.1)],
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
        let shortName = sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????"
        
        HStack(spacing: 6) {
            // Radio icon in rounded container
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isConnected ? AppColors.successGreen.opacity(0.2) : AppColors.errorRed.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isConnected ? AppColors.successGreen : AppColors.errorRed)
            }
            
            Text(shortName)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let batteryLevel = sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
        let signalStrength = sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength"))
        
        HStack(spacing: 8) {
            BatteryPill(level: batteryLevel)
            SignalBars(strength: signalStrength)
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let deviceName = sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic"
        
        Text(deviceName)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
            // Channel stats (left)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ch. Util: \(String(format: "%.1f", channelUtil))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Text("Airtime: \(String(format: "%.1f", airtime))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // TX/RX (center)
            VStack(spacing: 2) {
                Text("TX: \(sentPackets)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Text("RX: \(receivedPackets)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // Nodes online (right) - prominent badge
            NodesBadge(count: nodesOnline)
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
        
        ZStack {
            Circle()
                .fill(isConnected ? AppColors.successGreen.opacity(0.2) : AppColors.errorRed.opacity(0.2))
                .frame(width: 22, height: 22)
            
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isConnected ? AppColors.successGreen : AppColors.errorRed)
        }
    }
}

@available(iOS 16.2, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let batteryLevel = sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
        
        HStack(spacing: 4) {
            Text("\(batteryLevel)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
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
        
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(isConnected ? AppColors.successGreen : AppColors.errorRed)
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
    
    var snr: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("snr"))
    }
    
    var totalNodes: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("totalNodes"))
    }
    
    var uptimeSeconds: Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey("uptimeSeconds"))
    }
    
    var temperature: Double {
        sharedDefault.double(forKey: context.attributes.prefixedKey("temperature"))
    }
    
    var formattedUptime: String {
        let hours = uptimeSeconds / 3600
        let minutes = (uptimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row with device info
            HStack(alignment: .center, spacing: 8) {
                // Connection status icon with glow
                ZStack {
                    Circle()
                        .fill(isConnected ? AppColors.successGreen.opacity(0.15) : AppColors.errorRed.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isConnected ? AppColors.successGreen : AppColors.errorRed)
                }
                
                Text(shortName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Text(deviceName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                HStack(spacing: 8) {
                    BatteryPill(level: batteryLevel)
                    SignalIndicator(strength: signalStrength)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Gradient progress bars for Channel Util & Airtime
            VStack(spacing: 6) {
                ProgressBar(
                    label: "Channel Utilization",
                    value: channelUtilization,
                    gradient: LinearGradient(
                        colors: [AppColors.purple, AppColors.magenta],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                ProgressBar(
                    label: "Airtime TX",
                    value: airtime,
                    gradient: LinearGradient(
                        colors: [AppColors.blue, AppColors.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            // Stats grid at bottom
            HStack(spacing: 0) {
                // TX
                MiniStatCard(icon: "arrow.up", value: "\(sentPackets)", label: "TX", color: AppColors.magenta)
                
                Spacer()
                
                // RX
                MiniStatCard(icon: "arrow.down", value: "\(receivedPackets)", label: "RX", color: AppColors.successGreen)
                
                Spacer()
                
                // SNR
                MiniStatCard(icon: "waveform", value: "\(snr)", label: "SNR", color: AppColors.blue)
                
                Spacer()
                
                // Uptime (if available)
                if uptimeSeconds > 0 {
                    MiniStatCard(icon: "clock", value: formattedUptime, label: "UP", color: AppColors.purple)
                    Spacer()
                }
                
                // Nodes online badge - prominent
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(nodesOnline)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    if totalNodes > 0 {
                        Text("/\(totalNodes)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .opacity(0.7)
                    }
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.successGreen)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Reusable Components

// Gradient progress bar
struct ProgressBar: View {
    let label: String
    let value: Double
    let gradient: LinearGradient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.darkBorder.opacity(0.3))
                        .frame(height: 6)
                    
                    // Gradient fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gradient)
                        .frame(
                            width: max(4, geometry.size.width * CGFloat(min(value, 100.0)) / 100.0),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }
}

// Mini stat card for bottom row
struct MiniStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .textCase(.uppercase)
        }
    }
}

// Compact stat card
struct CompactStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                    .textCase(.uppercase)
            }
        }
    }
}

// Nodes badge
struct NodesBadge: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.successGreen)
        )
    }
}

// Battery pill with fill indicator (like iPhone battery)
struct BatteryPill: View {
    let level: Int
    
    var color: Color {
        if level <= 20 { return AppColors.errorRed }
        if level <= 50 { return AppColors.warningYellow }
        return AppColors.successGreen
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Battery outline with fill
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color, lineWidth: 1)
                    .frame(width: 22, height: 11)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(2, CGFloat(level) / 100.0 * 18), height: 7)
                    .padding(.leading, 2)
            }
            
            Text("\(level)%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

// Signal strength indicator with gradient bars
struct SignalIndicator: View {
    let strength: Int
    
    var signalBars: Int {
        if strength >= -50 { return 4 }
        if strength >= -70 { return 3 }
        if strength >= -85 { return 2 }
        if strength >= -100 { return 1 }
        return 0
    }
    
    var gradient: LinearGradient {
        if signalBars >= 3 {
            return LinearGradient(
                colors: [AppColors.successGreen, AppColors.successGreen.opacity(0.7)],
                startPoint: .bottom,
                endPoint: .top
            )
        } else if signalBars >= 2 {
            return LinearGradient(
                colors: [AppColors.warningYellow, AppColors.warningYellow.opacity(0.7)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        return LinearGradient(
            colors: [AppColors.errorRed, AppColors.errorRed.opacity(0.7)],
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < signalBars ? gradient : LinearGradient(colors: [AppColors.darkBorder], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3.5, height: CGFloat(5 + index * 3))
            }
        }
    }
}

struct SignalBars: View {
    let strength: Int
    
    var body: some View {
        SignalIndicator(strength: strength)
    }
}
