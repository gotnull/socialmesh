//
//  SocialmeshWidgetsLiveActivity.swift
//  SocialmeshWidgets
//
//  Socialmesh Live Activity — Lock Screen, Dynamic Island, CarPlay
//  Clean layout, no blur/glow hacks, CarPlay-safe rendering
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared UserDefaults

private var sharedDefault: UserDefaults {
    UserDefaults(suiteName: "group.com.gotnull.socialmesh") ?? UserDefaults.standard
}

// MARK: - Design Tokens

struct SM {
    // Brand
    static let accent = Color(red: 233/255, green: 30/255, blue: 140/255)

    // Semantic
    static let green = Color(red: 52/255, green: 199/255, blue: 89/255)
    static let orange = Color(red: 255/255, green: 149/255, blue: 0/255)
    static let red = Color(red: 255/255, green: 59/255, blue: 48/255)
    static let purple = Color(red: 175/255, green: 82/255, blue: 222/255)
    static let cyan = Color(red: 50/255, green: 173/255, blue: 230/255)

    // Neutral
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.55)
    static let textTertiary = Color(white: 0.35)
    static let fill = Color(white: 0.12)
    static let separator = Color(white: 0.18)

    // Typography — monospaced for data, rounded for brand, default for labels
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func brand(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Signal quality
    static func signalColor(_ rssi: Int) -> Color {
        if rssi >= -70 { return green }
        if rssi >= -90 { return orange }
        return red
    }

    // SNR quality
    static func snrColor(_ snr: Int) -> Color {
        if snr >= 5 { return green }
        if snr >= 0 { return orange }
        return red
    }

    // Battery level
    static func batteryColor(_ level: Int) -> Color {
        if level <= 20 { return red }
        if level <= 40 { return orange }
        return green
    }
}

// MARK: - UserDefaults Key Helper

@available(iOS 16.2, *)
struct LiveData {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    private func key(_ name: String) -> String {
        context.attributes.prefixedKey(name)
    }

    private func string(_ name: String) -> String {
        sharedDefault.string(forKey: key(name)) ?? ""
    }

    private func int(_ name: String) -> Int {
        sharedDefault.integer(forKey: key(name))
    }

    private func double(_ name: String) -> Double {
        sharedDefault.double(forKey: key(name))
    }

    private func bool(_ name: String) -> Bool {
        sharedDefault.bool(forKey: key(name))
    }

    // Device
    var deviceName: String { string("deviceName").isEmpty ? shortName : string("deviceName") }
    var shortName: String { let s = string("shortName"); return s.isEmpty ? "????" : s }
    var isConnected: Bool { bool("isConnected") }

    // Radio
    var battery: Int { int("batteryLevel") }
    var displayBattery: Int { min(battery, 100) }
    var isCharging: Bool { battery > 100 }
    var signal: Int { int("signalStrength") }
    var snr: Int { int("snr") }
    var channelUtil: Double { double("channelUtilization") }
    var airtime: Double { double("airtime") }

    // Network
    var nodesOnline: Int { int("nodesOnline") }
    var totalNodes: Int { int("totalNodes") }
    var tx: Int { int("sentPackets") }
    var rx: Int { int("receivedPackets") }

    // Environment
    var voltage: Double { double("voltage") }
}

// MARK: - Widget Entry Point

@available(iOS 16.2, *)
struct SocialmeshWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenView(data: LiveData(context: context))
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(SM.accent)
        } dynamicIsland: { context in
            let data = LiveData(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading, priority: 1) {
                    ExpandedLeading(data: data)
                }
                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    ExpandedTrailing(data: data)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(data: data)
                }
            } compactLeading: {
                CompactLeadingView(data: data)
            } compactTrailing: {
                CompactTrailingView(data: data)
            } minimal: {
                MinimalView(data: data)
            }
        }
    }
}

// MARK: - Lock Screen

@available(iOS 16.2, *)
struct LockScreenView: View {
    let data: LiveData

    var body: some View {
        VStack(spacing: 0) {
            // Header — brand + device + battery
            headerRow
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            // Accent separator
            Rectangle()
                .fill(SM.accent.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // Stats — signal, nodes, packets
            statsRow
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Footer — utilization bars
            footerRow
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            // Connection indicator + branding
            HStack(spacing: 8) {
                Circle()
                    .fill(data.isConnected ? SM.green : SM.red)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Socialmesh")
                        .font(SM.brand(13, weight: .bold))
                        .foregroundColor(SM.textPrimary)

                    Text(data.deviceName)
                        .font(SM.label(11, weight: .medium))
                        .foregroundColor(SM.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Battery
            batteryView
        }
    }

    private var batteryView: some View {
        HStack(spacing: 5) {
            if data.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(SM.green)
            }

            // Battery bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(SM.fill)
                    .frame(width: 26, height: 11)

                RoundedRectangle(cornerRadius: 2)
                    .fill(SM.batteryColor(data.displayBattery))
                    .frame(
                        width: max(3, CGFloat(data.displayBattery) / 100.0 * 22),
                        height: 7
                    )
                    .padding(.leading, 2)
            }

            // Terminal nub
            RoundedRectangle(cornerRadius: 0.5)
                .fill(SM.batteryColor(data.displayBattery).opacity(0.6))
                .frame(width: 1.5, height: 5)

            Text("\(data.displayBattery)%")
                .font(SM.mono(12, weight: .bold))
                .foregroundColor(SM.batteryColor(data.displayBattery))
                .frame(minWidth: 32, alignment: .trailing)
        }
    }

    // MARK: Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Signal
            signalCell
                .frame(maxWidth: .infinity)

            verticalDivider

            // Nodes
            nodesCell
                .frame(maxWidth: .infinity)

            verticalDivider

            // Packets
            packetsCell
                .frame(maxWidth: .infinity)
        }
    }

    private var signalCell: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                SignalBars(rssi: data.signal)
                Text("\(data.signal)")
                    .font(SM.mono(18, weight: .heavy))
                    .foregroundColor(SM.signalColor(data.signal))
            }

            Text("dBm")
                .font(SM.mono(8, weight: .semibold))
                .foregroundColor(SM.textTertiary)
                .textCase(.uppercase)

            snrBadge
        }
    }

    private var snrBadge: some View {
        HStack(spacing: 2) {
            Text("SNR")
                .font(SM.mono(7, weight: .bold))
                .foregroundColor(SM.textTertiary)
            Text("\(data.snr >= 0 ? "+" : "")\(data.snr)")
                .font(SM.mono(9, weight: .bold))
                .foregroundColor(SM.snrColor(data.snr))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(SM.fill)
        )
    }

    private var nodesCell: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(data.nodesOnline)")
                    .font(SM.mono(28, weight: .black))
                    .foregroundColor(SM.green)
                Text("/\(data.totalNodes)")
                    .font(SM.mono(13, weight: .medium))
                    .foregroundColor(SM.textTertiary)
            }

            Text("NODES")
                .font(SM.mono(8, weight: .bold))
                .foregroundColor(SM.textTertiary)
                .tracking(1.5)
        }
    }

    private var packetsCell: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(SM.accent)
                Text("\(data.tx)")
                    .font(SM.mono(14, weight: .bold))
                    .foregroundColor(SM.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(SM.green)
                Text("\(data.rx)")
                    .font(SM.mono(14, weight: .bold))
                    .foregroundColor(SM.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(SM.separator)
            .frame(width: 1, height: 40)
    }

    // MARK: Footer — Utilization

    private var footerRow: some View {
        HStack(spacing: 12) {
            UtilizationBar(label: "CH", value: data.channelUtil, color: SM.purple)
            UtilizationBar(label: "AIR", value: data.airtime, color: SM.cyan)

            if data.voltage > 0 {
                Spacer(minLength: 4)
                voltagePill
            }
        }
    }

    private var voltagePill: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(SM.cyan)
            Text(String(format: "%.1fV", data.voltage))
                .font(SM.mono(10, weight: .bold))
                .foregroundColor(SM.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(SM.fill)
        )
    }
}

// MARK: - Utilization Bar (shared between Lock Screen and DI)

struct UtilizationBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(SM.mono(9, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SM.fill)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(2, geo.size.width * CGFloat(min(value, 100) / 100)))
                }
            }
            .frame(height: 6)

            Text(String(format: "%.0f%%", value))
                .font(SM.mono(9, weight: .bold))
                .foregroundColor(SM.textPrimary)
                .frame(width: 30, alignment: .leading)
        }
    }
}

// MARK: - Signal Bars

struct SignalBars: View {
    let rssi: Int

    private var filled: Int {
        if rssi >= -60 { return 4 }
        if rssi >= -75 { return 3 }
        if rssi >= -90 { return 2 }
        if rssi >= -100 { return 1 }
        return 0
    }

    private var color: Color { SM.signalColor(rssi) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < filled ? color : SM.fill)
                    .frame(width: 3, height: CGFloat(6 + i * 3))
            }
        }
    }
}

// MARK: - Dynamic Island: Compact

@available(iOS 16.2, *)
struct CompactLeadingView: View {
    let data: LiveData

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(data.isConnected ? SM.green : SM.red)
                .frame(width: 8, height: 8)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SM.textPrimary)
        }
    }
}

@available(iOS 16.2, *)
struct CompactTrailingView: View {
    let data: LiveData

    var body: some View {
        Text("\(data.nodesOnline)")
            .font(SM.mono(15, weight: .bold))
            .foregroundColor(SM.green)
    }
}

// MARK: - Dynamic Island: Minimal

@available(iOS 16.2, *)
struct MinimalView: View {
    let data: LiveData

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    data.isConnected ? SM.green.opacity(0.4) : SM.red.opacity(0.4),
                    lineWidth: 1.5
                )
            Text("\(data.nodesOnline)")
                .font(SM.mono(13, weight: .heavy))
                .foregroundColor(data.isConnected ? SM.green : SM.red)
        }
    }
}

// MARK: - Dynamic Island: Expanded

@available(iOS 16.2, *)
struct ExpandedLeading: View {
    let data: LiveData

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(data.isConnected ? SM.green : SM.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text("Socialmesh")
                    .font(SM.brand(12, weight: .bold))
                    .foregroundColor(SM.textPrimary)

                Text(data.deviceName)
                    .font(SM.label(10, weight: .medium))
                    .foregroundColor(SM.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 2)
    }
}

@available(iOS 16.2, *)
struct ExpandedTrailing: View {
    let data: LiveData

    var body: some View {
        HStack(spacing: 10) {
            // Nodes
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(data.nodesOnline)")
                        .font(SM.mono(17, weight: .black))
                        .foregroundColor(SM.green)
                    Text("/\(data.totalNodes)")
                        .font(SM.mono(11, weight: .medium))
                        .foregroundColor(SM.textTertiary)
                }
                Text("NODES")
                    .font(SM.mono(6, weight: .bold))
                    .foregroundColor(SM.textTertiary)
                    .tracking(1)
            }

            // Battery
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    if data.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundColor(SM.green)
                    }

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(SM.fill)
                            .frame(width: 22, height: 10)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(SM.batteryColor(data.displayBattery))
                            .frame(
                                width: max(2, CGFloat(data.displayBattery) / 100.0 * 18),
                                height: 6
                            )
                            .padding(.leading, 2)
                    }

                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(SM.batteryColor(data.displayBattery).opacity(0.5))
                        .frame(width: 1.5, height: 4)
                }

                Text("\(data.displayBattery)%")
                    .font(SM.mono(11, weight: .bold))
                    .foregroundColor(SM.batteryColor(data.displayBattery))
            }
        }
        .padding(.trailing, 2)
    }
}

@available(iOS 16.2, *)
struct ExpandedBottom: View {
    let data: LiveData

    var body: some View {
        HStack(spacing: 0) {
            // Signal
            HStack(spacing: 3) {
                SignalBars(rssi: data.signal)
                Text("\(data.signal)")
                    .font(SM.mono(12, weight: .bold))
                    .foregroundColor(SM.signalColor(data.signal))
                Text("dBm")
                    .font(SM.mono(7, weight: .semibold))
                    .foregroundColor(SM.textTertiary)
            }

            Spacer(minLength: 4)

            // SNR
            HStack(spacing: 2) {
                Text("SNR")
                    .font(SM.mono(8, weight: .bold))
                    .foregroundColor(SM.textTertiary)
                Text("\(data.snr >= 0 ? "+" : "")\(data.snr)")
                    .font(SM.mono(12, weight: .bold))
                    .foregroundColor(SM.snrColor(data.snr))
            }

            Spacer(minLength: 4)

            // Channel + Airtime
            HStack(spacing: 8) {
                DIUtilPill(label: "CH", value: data.channelUtil, color: SM.purple)
                DIUtilPill(label: "AIR", value: data.airtime, color: SM.cyan)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - DI Utilization Pill

struct DIUtilPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(SM.mono(8, weight: .bold))
                .foregroundColor(color)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SM.fill)
                    .frame(width: 28, height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(
                        width: max(2, CGFloat(min(value, 100) / 100) * 28),
                        height: 4
                    )
            }

            Text(String(format: "%.0f", value))
                .font(SM.mono(8, weight: .bold))
                .foregroundColor(SM.textPrimary)
        }
    }
}
