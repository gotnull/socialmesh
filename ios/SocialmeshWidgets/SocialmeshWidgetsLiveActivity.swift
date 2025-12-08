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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack {
                // Left: Radio icon + Short name (like "✈ UA2645")
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isConnected ? AppColors.successGreen : AppColors.errorRed)
                    
                    Text(shortName)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                // Center: Device name
                Text(deviceName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                // Right: Battery + Signal (like Flighty "FLIGHTY" label area)
                HStack(spacing: 6) {
                    BatteryPill(level: batteryLevel)
                    SignalBars(strength: signalStrength)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            // MARK: Stats Row - Clean grid like Fitness app
            HStack(spacing: 12) {
                // Channel Utilization Card
                StatCard(
                    label: "Ch. Util",
                    value: String(format: "%.1f", channelUtilization),
                    unit: "%",
                    color: AppColors.purple
                )
                
                // Airtime Card
                StatCard(
                    label: "Airtime",
                    value: String(format: "%.1f", airtime),
                    unit: "%",
                    color: AppColors.blue
                )
                
                // TX Card
                StatCard(
                    label: "TX",
                    value: "\(sentPackets)",
                    unit: nil,
                    color: AppColors.magenta
                )
                
                // RX Card
                StatCard(
                    label: "RX",
                    value: "\(receivedPackets)",
                    unit: nil,
                    color: AppColors.successGreen
                )
                
                // Nodes Online Badge (prominent, like Flighty luggage badge)
                NodesBadge(count: nodesOnline)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Reusable Components

// Compact stat card like Fitness app grid items
struct StatCard: View {
    let label: String
    let value: String
    let unit: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(color.opacity(0.8))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

// Prominent badge for nodes online (like Flighty's luggage count badge)
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

struct SignalBars: View {
    let strength: Int
    
    var signalBars: Int {
        if strength >= -50 { return 4 }
        if strength >= -70 { return 3 }
        if strength >= -85 { return 2 }
        if strength >= -100 { return 1 }
        return 0
    }
    
    var color: Color {
        if signalBars >= 3 { return AppColors.successGreen }
        if signalBars >= 2 { return AppColors.warningYellow }
        return AppColors.errorRed
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < signalBars ? color : AppColors.darkBorder)
                    .frame(width: 3, height: CGFloat(4 + index * 3))
            }
        }
    }
}
