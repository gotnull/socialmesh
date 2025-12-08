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

// MARK: - Design System
struct Design {
    // Colors
    static let accent = Color(red: 233/255, green: 30/255, blue: 140/255)
    static let green = Color(red: 48/255, green: 209/255, blue: 88/255)
    static let orange = Color(red: 255/255, green: 159/255, blue: 10/255)
    static let red = Color(red: 255/255, green: 69/255, blue: 58/255)
    static let blue = Color(red: 10/255, green: 132/255, blue: 255/255)
    static let purple = Color(red: 175/255, green: 82/255, blue: 222/255)
    static let cyan = Color(red: 50/255, green: 173/255, blue: 230/255)
    static let teal = Color(red: 48/255, green: 176/255, blue: 199/255)
    static let white = Color.white
    static let secondary = Color(white: 0.6)
    static let tertiary = Color(white: 0.4)
    static let separator = Color(white: 0.2)
    static let cardBg = Color(white: 0.1)
    
    // Gradients
    static let meshGradient = LinearGradient(
        colors: [accent, purple, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

@available(iOS 16.2, *)
struct SocialmeshWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(Design.accent)
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
        
        ZStack {
            Circle()
                .fill(isConnected ? Design.green.opacity(0.2) : Design.red.opacity(0.2))
                .frame(width: 24, height: 24)
            
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isConnected ? Design.green : Design.red)
        }
    }
}

@available(iOS 16.2, *)
struct CompactTrailing: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        let battery = sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel"))
        let isCharging = battery > 100
        
        HStack(spacing: 3) {
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Design.green)
            }
            
            Text("\(nodes)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(Design.green)
        }
    }
}

@available(iOS 16.2, *)
struct MinimalView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        
        Image(systemName: "\(min(nodes, 50)).circle.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Design.green)
    }
}

// MARK: - Expanded Views

@available(iOS 16.2, *)
struct ExpandedLeading: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let shortName = sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????"
        let deviceName = sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Mesh"
        let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
        
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isConnected ? Design.green : Design.red)
                    .frame(width: 8, height: 8)
                Text(shortName)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
            }
            Text(deviceName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Design.secondary)
                .lineLimit(1)
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
        let voltage = sharedDefault.double(forKey: context.attributes.prefixedKey("voltage"))
        
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 3) {
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Design.green)
                }
                DynamicIslandBattery(level: displayLevel)
            }
            if voltage > 0 {
                Text(String(format: "%.2fV", voltage))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.teal)
            }
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedCenter: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        let total = sharedDefault.integer(forKey: context.attributes.prefixedKey("totalNodes"))
        
        HStack(spacing: 4) {
            Image(systemName: "circle.hexagonpath.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Design.green)
            Text("\(nodes)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(Design.green)
            Text("/\(total)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Design.secondary)
        }
    }
}

@available(iOS 16.2, *)
struct ExpandedBottom: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var signal: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength")) }
    var snr: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("snr")) }
    var channel: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization")) }
    var airtime: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("airtime")) }
    var tx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("sentPackets")) }
    var rx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("receivedPackets")) }
    
    var body: some View {
        VStack(spacing: 6) {
            // Top row - Signal metrics
            HStack(spacing: 8) {
                DIMetric(icon: "antenna.radiowaves.left.and.right", value: "\(signal)", unit: "dBm", color: signalColor)
                DIMetric(icon: "waveform.badge.mic", value: snrFormatted, unit: "SNR", color: snrColor)
                DIMetric(icon: "chart.bar.fill", value: String(format: "%.0f", channel), unit: "CH%", color: chColor)
                DIMetric(icon: "wave.3.right", value: String(format: "%.1f", airtime), unit: "AIR%", color: airColor)
            }
            
            // Bottom row - Packets
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Design.accent)
                    Text("\(tx)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("TX")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Design.secondary)
                }
                
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Design.green)
                    Text("\(rx)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("RX")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Design.secondary)
                }
            }
        }
    }
    
    var snrFormatted: String {
        snr >= 0 ? "+\(snr)" : "\(snr)"
    }
    
    var signalColor: Color {
        if signal >= -80 { return Design.green }
        if signal >= -100 { return Design.orange }
        return Design.red
    }
    
    var snrColor: Color {
        if snr >= 5 { return Design.green }
        if snr >= 0 { return Design.orange }
        return Design.red
    }
    
    var chColor: Color {
        if channel <= 30 { return Design.green }
        if channel <= 60 { return Design.orange }
        return Design.red
    }
    
    var airColor: Color {
        if airtime <= 10 { return Design.green }
        if airtime <= 25 { return Design.orange }
        return Design.red
    }
}

struct DIMetric: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Design.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DynamicIslandBattery: View {
    let level: Int
    
    var color: Color {
        if level <= 20 { return Design.red }
        if level <= 50 { return Design.orange }
        return Design.green
    }
    
    var body: some View {
        HStack(spacing: 3) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color.opacity(0.4), lineWidth: 1)
                    .frame(width: 20, height: 9)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: max(2, CGFloat(level) / 100 * 16), height: 5)
                    .padding(.leading, 2)
            }
            
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(width: 1, height: 3)
            
            Text("\(level)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
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
    var voltage: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("voltage")) }
    
    var isCharging: Bool { battery > 100 }
    var displayBattery: Int { min(battery, 100) }
    
    var body: some View {
        HStack(spacing: 12) {
            // Left column - Mesh visualization
            VStack(spacing: 4) {
                MiniMesh(nodes: nodes, isConnected: isConnected)
                    .frame(width: 60, height: 60)
                
                Text("\(nodes)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Design.green)
                
                Text("of \(totalNodes)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Design.secondary)
            }
            .frame(width: 70)
            
            // Right column - Stats
            VStack(spacing: 6) {
                // Header row
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isConnected ? Design.green : Design.red)
                            .frame(width: 8, height: 8)
                        Text(shortName)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Design.green)
                        }
                        BatteryIcon(level: displayBattery)
                    }
                }
                
                // Stats grid - 2x2
                HStack(spacing: 6) {
                    StatBox(value: "\(signal)", unit: "dBm", color: signalColor(signal))
                    StatBox(value: snrFormatted, unit: "SNR", color: snrColor)
                }
                
                HStack(spacing: 6) {
                    StatBox(value: String(format: "%.0f", channel), unit: "CH%", color: utilizationColor(channel))
                    StatBox(value: String(format: "%.1f", airtime), unit: "AIR%", color: utilizationColor(airtime))
                }
                
                // Bottom row - TX/RX and voltage
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Design.accent)
                        Text("\(tx)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Design.green)
                        Text("\(rx)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    if voltage > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Design.teal)
                            Text(String(format: "%.1fV", voltage))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
    
    var snrFormatted: String {
        if snr >= 0 { return "+\(snr)" }
        return "\(snr)"
    }
    
    var snrColor: Color {
        if snr >= 5 { return Design.green }
        if snr >= 0 { return Design.orange }
        return Design.red
    }
    
    func signalColor(_ rssi: Int) -> Color {
        if rssi >= -80 { return Design.green }
        if rssi >= -100 { return Design.orange }
        return Design.red
    }
    
    func utilizationColor(_ value: Double) -> Color {
        if value <= 30 { return Design.green }
        if value <= 60 { return Design.orange }
        return Design.red
    }
}

// MARK: - Components

struct MiniMesh: View {
    let nodes: Int
    let isConnected: Bool
    
    var body: some View {
        ZStack {
            // Rings
            Circle()
                .stroke(Design.accent.opacity(0.1), lineWidth: 1)
                .frame(width: 54, height: 54)
            Circle()
                .stroke(Design.accent.opacity(0.15), lineWidth: 1)
                .frame(width: 36, height: 36)
            
            // Node dots
            ForEach(0..<min(nodes, 6), id: \.self) { i in
                let angle = Double(i) * (360.0 / Double(min(nodes, 6))) * .pi / 180
                Circle()
                    .fill(Design.green)
                    .frame(width: 5, height: 5)
                    .offset(x: cos(angle) * 22, y: sin(angle) * 22)
            }
            
            // Center node
            Circle()
                .fill(isConnected ? Design.accent : Design.red)
                .frame(width: 10, height: 10)
        }
    }
}

struct StatBox: View {
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Design.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Design.cardBg)
        .cornerRadius(6)
    }
}

struct BatteryIcon: View {
    let level: Int
    
    var color: Color {
        if level <= 20 { return Design.red }
        if level <= 50 { return Design.orange }
        return Design.green
    }
    
    var body: some View {
        HStack(spacing: 3) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color.opacity(0.5), lineWidth: 1)
                    .frame(width: 22, height: 10)
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: max(2, CGFloat(level) / 100 * 18), height: 6)
                    .padding(.leading, 2)
            }
            
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(width: 1.5, height: 4)
            
            Text("\(level)%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}
