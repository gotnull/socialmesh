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
    static let accent = Color(red: 233/255, green: 30/255, blue: 140/255)
    static let green = Color(red: 52/255, green: 199/255, blue: 89/255)
    static let orange = Color(red: 255/255, green: 149/255, blue: 0/255)
    static let red = Color(red: 255/255, green: 59/255, blue: 48/255)
    static let blue = Color(red: 0/255, green: 122/255, blue: 255/255)
    static let purple = Color(red: 175/255, green: 82/255, blue: 222/255)
    static let cyan = Color(red: 50/255, green: 173/255, blue: 230/255)
    static let teal = Color(red: 90/255, green: 200/255, blue: 250/255)
    static let dim = Color(white: 0.5)
    static let dimmer = Color(white: 0.15)
    
    // Background colors for sci-fi aesthetic
    static let backgroundDark = Color(red: 18/255, green: 18/255, blue: 22/255)
    static let backgroundCard = Color(red: 28/255, green: 28/255, blue: 35/255)
    static let glowAccent = accent.opacity(0.15)
    
    // Fonts - SF Mono matches JetBrains Mono style
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

@available(iOS 16.2, *)
struct SocialmeshWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Design.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading, priority: 1) {
                    DILeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    DITrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DIBottom(context: context)
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

// MARK: - Compact Dynamic Island

@available(iOS 16.2, *)
struct CompactLeading: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let isConnected = sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected"))
        
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Design.green : Design.red)
                .frame(width: 8, height: 8)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

@available(iOS 16.2, *)
struct CompactTrailing: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        
        Text("\(nodes)")
            .font(Design.mono(16, weight: .bold))
            .foregroundColor(Design.green)
    }
}

@available(iOS 16.2, *)
struct MinimalView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let nodes = sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline"))
        
        ZStack {
            Circle()
                .strokeBorder(Design.green.opacity(0.3), lineWidth: 2)
            Text("\(nodes)")
                .font(Design.mono(14, weight: .heavy))
                .foregroundColor(Design.green)
        }
    }
}

// MARK: - Expanded Dynamic Island

@available(iOS 16.2, *)
struct DILeading: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var shortName: String { sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????" }
    var deviceName: String { sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "" }
    var isConnected: Bool { sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected")) }
    var signal: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength")) }
    var snr: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("snr")) }
    
    var body: some View {
        HStack(spacing: 8) {
            // Signal arc (mini version)
            ZStack {
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Design.dimmer, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(90))
                
                Circle()
                    .trim(from: 0.25, to: 0.25 + signalPercent * 0.5)
                    .stroke(
                        LinearGradient(colors: [signalColor(signal), signalColor(signal).opacity(0.5)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(90))
                
                Text("\(signal)")
                    .font(Design.mono(10, weight: .black))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Design.green : Design.red)
                        .frame(width: 6, height: 6)
                    Text(shortName)
                        .font(Design.mono(13, weight: .heavy))
                        .foregroundColor(.white)
                }
                if !deviceName.isEmpty {
                    Text(deviceName)
                        .font(Design.text(9, weight: .medium))
                        .foregroundColor(Design.dim)
                        .lineLimit(1)
                }
            }
        }
        .padding(.leading, 2)
    }
    
    var signalPercent: CGFloat {
        CGFloat(max(0, min(100, (signal + 120) * 100 / 90))) / 100
    }
    
    func signalColor(_ rssi: Int) -> Color {
        if rssi >= -70 { return Design.green }
        if rssi >= -90 { return Design.orange }
        return Design.red
    }
}

@available(iOS 16.2, *)
struct DITrailing: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var battery: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel")) }
    var nodes: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline")) }
    var total: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("totalNodes")) }
    
    var isCharging: Bool { battery > 100 }
    var level: Int { min(battery, 100) }
    
    var body: some View {
        HStack(spacing: 10) {
            // Node count
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("\(nodes)")
                        .font(Design.mono(18, weight: .black))
                        .foregroundColor(Design.green)
                    Text("/\(total)")
                        .font(Design.mono(12, weight: .medium))
                        .foregroundColor(Design.dim)
                }
                Text("NODES")
                    .font(Design.mono(6, weight: .bold))
                    .foregroundColor(Design.dim)
                    .tracking(1)
            }
            
            // Battery
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    if isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Design.green)
                    }
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Design.dimmer)
                            .frame(width: 22, height: 10)
                        
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(LinearGradient(colors: [batteryColor(level), batteryColor(level).opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, CGFloat(level) / 100 * 18), height: 6)
                            .padding(.leading, 2)
                    }
                    
                    Rectangle()
                        .fill(batteryColor(level).opacity(0.5))
                        .frame(width: 1.5, height: 4)
                        .cornerRadius(1)
                }
                
                Text("\(level)%")
                    .font(Design.mono(11, weight: .bold))
                    .foregroundColor(batteryColor(level))
            }
        }
        .padding(.trailing, 2)
    }
    
    func batteryColor(_ level: Int) -> Color {
        if level <= 20 { return Design.red }
        if level <= 40 { return Design.orange }
        return Design.green
    }
}

@available(iOS 16.2, *)
struct DIBottom: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var channel: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization")) }
    var airtime: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("airtime")) }
    var snr: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("snr")) }
    var tx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("sentPackets")) }
    var rx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("receivedPackets")) }
    
    var body: some View {
        HStack(spacing: 12) {
            // Utilization bars - styled like lock screen
            HStack(spacing: 8) {
                DIUtilBar(value: channel, label: "CH", color: Design.purple)
                DIUtilBar(value: airtime, label: "AIR", color: Design.cyan)
            }
            
            // Separator
            Rectangle()
                .fill(Design.dimmer)
                .frame(width: 1, height: 20)
            
            // SNR
            VStack(spacing: 0) {
                Text("\(snr >= 0 ? "+" : "")\(snr)")
                    .font(Design.mono(14, weight: .bold))
                    .foregroundColor(snrColor(snr))
                Text("SNR")
                    .font(Design.mono(7, weight: .bold))
                    .foregroundColor(Design.dim)
            }
            
            // Separator
            Rectangle()
                .fill(Design.dimmer)
                .frame(width: 1, height: 20)
            
            // TX/RX
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Design.accent)
                    Text("\(tx)")
                        .font(Design.mono(10, weight: .bold))
                        .foregroundColor(.white)
                }
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Design.green)
                    Text("\(rx)")
                        .font(Design.mono(10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    func snrColor(_ snr: Int) -> Color {
        if snr >= 5 { return Design.green }
        if snr >= 0 { return Design.orange }
        return Design.red
    }
}

// DI-specific utilization bar - horizontal layout
struct DIUtilBar: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Design.mono(9, weight: .bold))
                .foregroundColor(color)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Design.dimmer)
                    .frame(width: 36, height: 5)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [color, color.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(2, CGFloat(min(value, 100) / 100) * 36), height: 5)
            }
            
            Text(String(format: "%.0f", value))
                .font(Design.mono(9, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>
    
    // Device info
    var shortName: String { sharedDefault.string(forKey: context.attributes.prefixedKey("shortName")) ?? "????" }
    var deviceName: String { sharedDefault.string(forKey: context.attributes.prefixedKey("deviceName")) ?? "Meshtastic" }
    var isConnected: Bool { sharedDefault.bool(forKey: context.attributes.prefixedKey("isConnected")) }
    var role: String { sharedDefault.string(forKey: context.attributes.prefixedKey("role")) ?? "" }
    var firmware: String { sharedDefault.string(forKey: context.attributes.prefixedKey("firmwareVersion")) ?? "" }
    var hardware: String { sharedDefault.string(forKey: context.attributes.prefixedKey("hardwareModel")) ?? "" }
    
    // Radio stats
    var battery: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("batteryLevel")) }
    var signal: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("signalStrength")) }
    var snr: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("snr")) }
    var channel: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("channelUtilization")) }
    var airtime: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("airtime")) }
    
    // Network stats
    var nodes: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("nodesOnline")) }
    var totalNodes: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("totalNodes")) }
    var tx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("sentPackets")) }
    var rx: Int { sharedDefault.integer(forKey: context.attributes.prefixedKey("receivedPackets")) }
    
    // Environment
    var voltage: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("voltage")) }
    var temperature: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("temperature")) }
    var humidity: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("humidity")) }
    
    // Nearest node
    var nearestDistance: Double { sharedDefault.double(forKey: context.attributes.prefixedKey("nearestNodeDistance")) }
    var nearestName: String { sharedDefault.string(forKey: context.attributes.prefixedKey("nearestNodeName")) ?? "" }
    
    var isCharging: Bool { battery > 100 }
    var displayBattery: Int { min(battery, 100) }
    
    var body: some View {
        ZStack {
            // Sci-fi gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Design.backgroundCard,
                            Design.backgroundDark,
                            Design.backgroundDark.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle glow border
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Design.accent.opacity(0.4),
                            Design.accent.opacity(0.1),
                            Design.cyan.opacity(0.2),
                            Design.accent.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            // Inner content
            VStack(spacing: 0) {
                // Top row - Device ID + Battery
                HStack {
                    // Status + Name
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(isConnected ? Design.green.opacity(0.2) : Design.red.opacity(0.2))
                                .frame(width: 18, height: 18)
                            Circle()
                                .fill(isConnected ? Design.green : Design.red)
                                .frame(width: 8, height: 8)
                                .shadow(color: isConnected ? Design.green.opacity(0.6) : Design.red.opacity(0.6), radius: 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text("MESH")
                                    .font(Design.mono(11, weight: .heavy))
                                    .foregroundColor(.white)
                                    .tracking(1)
                            }
                            
                            Text(deviceName.isEmpty ? shortName : deviceName)
                                .font(Design.text(11, weight: .medium))
                                .foregroundColor(Design.dim)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Battery with glow
                    HStack(spacing: 4) {
                        if isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Design.green)
                                .shadow(color: Design.green.opacity(0.6), radius: 3)
                        }
                        
                        // Battery bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Design.dimmer)
                                .frame(width: 28, height: 12)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(batteryGradient)
                                .frame(width: max(3, CGFloat(displayBattery) / 100 * 24), height: 8)
                                .padding(.leading, 2)
                                .shadow(color: batteryColor.opacity(0.4), radius: 2)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(batteryColor.opacity(0.3), lineWidth: 0.5)
                                .frame(width: 28, height: 12)
                        }
                        
                        Rectangle()
                            .fill(batteryColor.opacity(0.5))
                            .frame(width: 2, height: 5)
                            .cornerRadius(1)
                        
                        Text("\(displayBattery)%")
                            .font(Design.mono(12, weight: .bold))
                            .foregroundColor(batteryColor)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Gradient separator with glow
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(colors: [Design.accent.opacity(0), Design.accent.opacity(0.5), Design.accent.opacity(0)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .blur(radius: 1)
                    Rectangle()
                        .fill(LinearGradient(colors: [Design.accent.opacity(0), Design.accent.opacity(0.8), Design.accent.opacity(0)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 16)
            
                // Main content grid
                HStack(spacing: 10) {
                    // Left column - Signal meter with glow
                    VStack(spacing: 4) {
                        // Signal meter
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(signalColor.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .blur(radius: 8)
                            
                            // Background arc
                            Circle()
                                .trim(from: 0.25, to: 0.75)
                                .stroke(Design.dimmer, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(90))
                            
                            // Signal arc
                            Circle()
                                .trim(from: 0.25, to: 0.25 + signalPercent * 0.5)
                                .stroke(
                                    LinearGradient(colors: [signalColor, signalColor.opacity(0.4)], startPoint: .leading, endPoint: .trailing),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(90))
                                .shadow(color: signalColor.opacity(0.5), radius: 3)
                            
                            VStack(spacing: -2) {
                                Text("\(signal)")
                                    .font(Design.mono(14, weight: .black))
                                    .foregroundColor(.white)
                                Text("dBm")
                                    .font(Design.mono(7, weight: .bold))
                                    .foregroundColor(Design.dim)
                            }
                        }
                        
                        // SNR badge
                        HStack(spacing: 2) {
                            Text("SNR")
                                .font(Design.mono(7, weight: .bold))
                                .foregroundColor(Design.dim)
                            Text("\(snr >= 0 ? "+" : "")\(snr)")
                                .font(Design.mono(10, weight: .bold))
                                .foregroundColor(snrColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Design.dimmer)
                        .cornerRadius(4)
                    }
                    .frame(width: 62)
                    
                    // Center column - Mesh + Utilization
                    VStack(spacing: 6) {
                        // Node count with glow
                        ZStack {
                            // Glow behind node count
                            Text("\(nodes)")
                                .font(Design.mono(32, weight: .black))
                                .foregroundColor(Design.green)
                                .blur(radius: 8)
                                .opacity(0.4)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 0) {
                                Text("\(nodes)")
                                    .font(Design.mono(32, weight: .black))
                                    .foregroundColor(Design.green)
                                Text("/\(totalNodes)")
                                    .font(Design.mono(14, weight: .medium))
                                    .foregroundColor(Design.dim)
                            }
                        }
                        
                        Text("NODES")
                            .font(Design.mono(8, weight: .bold))
                            .foregroundColor(Design.dim)
                            .tracking(2)
                        
                        // Utilization bars - glass card style
                        HStack(spacing: 8) {
                            UtilBar(value: channel, label: "CH", color: Design.purple)
                            UtilBar(value: airtime, label: "AIR", color: Design.cyan)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Right column - Stats grid
                    VStack(spacing: 4) {
                        // TX/RX
                        HStack(spacing: 4) {
                            StatPill(icon: "arrow.up", value: "\(tx)", color: Design.accent)
                            StatPill(icon: "arrow.down", value: "\(rx)", color: Design.green)
                        }
                        
                        // Voltage
                        if voltage > 0 {
                            StatPill(icon: "bolt.fill", value: String(format: "%.1fV", voltage), color: Design.teal)
                        }
                    }
                    .frame(width: 88)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }
    
    // Computed properties
    var signalPercent: CGFloat {
        CGFloat(max(0, min(100, (signal + 120) * 100 / 90))) / 100
    }
    
    var signalColor: Color {
        if signal >= -70 { return Design.green }
        if signal >= -90 { return Design.orange }
        return Design.red
    }
    
    var snrColor: Color {
        if snr >= 5 { return Design.green }
        if snr >= 0 { return Design.orange }
        return Design.red
    }
    
    var batteryColor: Color {
        if displayBattery <= 20 { return Design.red }
        if displayBattery <= 40 { return Design.orange }
        return Design.green
    }
    
    var batteryGradient: LinearGradient {
        LinearGradient(colors: [batteryColor, batteryColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
    }
    
    func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        }
        return String(format: "%.0fm", meters)
    }
}

// MARK: - Compact Components

struct MiniSignalBars: View {
    let rssi: Int
    
    var filledBars: Int {
        if rssi >= -60 { return 4 }
        if rssi >= -75 { return 3 }
        if rssi >= -90 { return 2 }
        if rssi >= -100 { return 1 }
        return 0
    }
    
    var color: Color {
        if rssi >= -70 { return Design.green }
        if rssi >= -90 { return Design.orange }
        return Design.red
    }
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(i < filledBars ? color : Design.dimmer)
                    .frame(width: 3, height: CGFloat(5 + i * 2))
            }
        }
    }
}

struct MiniBar: View {
    let value: Double
    let max: Double
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(Design.mono(9, weight: .semibold))
                .foregroundColor(Design.dim)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Design.dimmer)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(value, max) / max))
                }
            }
            .frame(width: 40, height: 6)
            
            Text(String(format: "%.0f", value))
                .font(Design.mono(10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, alignment: .trailing)
        }
    }
}

struct UtilBar: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            // Progress bar with glow
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Design.dimmer)
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [color, color.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, CGFloat(min(value, 100) / 100) * 44), height: 6)
                    .shadow(color: color.opacity(0.5), radius: 2)
            }
            .frame(width: 44)
            
            HStack(spacing: 2) {
                Text(label)
                    .font(Design.mono(7, weight: .bold))
                    .foregroundColor(Design.dim)
                Text(String(format: "%.0f%%", value))
                    .font(Design.mono(8, weight: .bold))
                    .foregroundColor(color)
            }
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 2)
            Text(value)
                .font(Design.mono(10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Design.dimmer)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}
