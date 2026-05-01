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

    private func intArray(_ name: String) -> [Int] {
        (sharedDefault.array(forKey: key(name)) as? [NSNumber])?.map { $0.intValue } ?? []
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
    var uptimeSeconds: Int { int("uptimeSeconds") }

    // Route — Flighty-style "from → to" half of the lock screen card.
    var destinationLabel: String {
        let s = string("destinationLabel")
        return s.isEmpty ? "MESH" : s
    }
    var destinationLongName: String {
        let s = string("destinationLongName")
        return s.isEmpty ? "Whole network" : s
    }
    var destinationLastHeardSec: Int { int("destinationLastHeardSec") }
    var destinationNextEventSec: Int { int("destinationNextEventSec") }

    /// "ok" | "stale" | "lost" | "idle" — drives the right-side status pill.
    var linkStatus: String {
        let s = string("linkStatus")
        return s.isEmpty ? "idle" : s
    }

    /// Recent BLE RSSI samples (oldest first) feeding the aurora curve.
    var signalHistory: [Int] { intArray("signalHistory") }
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

// MARK: - Lock Screen — Flighty-aligned route + aurora layout

@available(iOS 16.2, *)
struct LockScreenView: View {
    let data: LiveData

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Rectangle()
                .fill(SM.accent.opacity(0.4))
                .frame(height: 1)
                .padding(.horizontal, 16)

            routeRow
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            heroFooter
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    // MARK: Header — connection dot + names · link-status pill

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(data.isConnected ? SM.green : SM.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(data.shortName.uppercased())
                    .font(SM.mono(13, weight: .heavy))
                    .foregroundColor(SM.textPrimary)
                    .tracking(0.6)
                    .lineLimit(1)

                Text(data.deviceName)
                    .font(SM.label(10.5, weight: .medium))
                    .foregroundColor(SM.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            LinkStatusPill(status: data.linkStatus)
        }
    }

    // MARK: Route Row — YOU · aurora · DESTINATION

    private var routeRow: some View {
        HStack(alignment: .center, spacing: 10) {
            // Origin — local node
            VStack(alignment: .leading, spacing: 2) {
                Text("YOU")
                    .font(SM.mono(8, weight: .bold))
                    .foregroundColor(SM.textTertiary)
                    .tracking(1.2)
                Text("\(data.signal)")
                    .font(SM.mono(20, weight: .heavy))
                    .foregroundColor(SM.signalColor(data.signal))
                Text("dBm")
                    .font(SM.mono(8, weight: .semibold))
                    .foregroundColor(SM.textTertiary)
                    .tracking(0.8)
            }
            .frame(minWidth: 56, alignment: .leading)

            // Aurora curve — RSSI history sparkline
            AuroraCurve(
                samples: data.signalHistory,
                color: SM.signalColor(data.signal)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 44)

            // Destination — mesh / best peer / active DM
            VStack(alignment: .trailing, spacing: 2) {
                Text(data.destinationLabel)
                    .font(SM.mono(13, weight: .heavy))
                    .foregroundColor(SM.textPrimary)
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(formatAge(data.destinationLastHeardSec))
                    .font(SM.mono(9, weight: .semibold))
                    .foregroundColor(SM.textTertiary)
                    .lineLimit(1)
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
    }

    // MARK: Hero Footer — battery · uptime · nodes online

    private var heroFooter: some View {
        HStack(spacing: 0) {
            HeroStat(
                icon: data.isCharging ? "bolt.fill" : "battery.100",
                value: "\(data.displayBattery)%",
                tint: SM.batteryColor(data.displayBattery)
            )
            .frame(maxWidth: .infinity)

            verticalDivider

            HeroStat(
                icon: "clock",
                value: formatUptime(data.uptimeSeconds),
                tint: SM.cyan
            )
            .frame(maxWidth: .infinity)

            verticalDivider

            HeroStat(
                icon: "person.2.fill",
                value: "\(data.nodesOnline)/\(data.totalNodes)",
                tint: SM.green
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(SM.separator)
            .frame(width: 1, height: 22)
    }
}

// MARK: - Aurora Curve — RSSI history sparkline

@available(iOS 16.2, *)
struct AuroraCurve: View {
    let samples: [Int]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if samples.count >= 2 {
                ZStack {
                    Path { p in drawCurve(in: geo.size, path: &p, close: true) }
                        .fill(LinearGradient(
                            colors: [color.opacity(0.45), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))

                    Path { p in drawCurve(in: geo.size, path: &p, close: false) }
                        .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            } else {
                // Empty state — dashed mid-line.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(SM.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }

    private func drawCurve(in size: CGSize, path: inout Path, close: Bool) {
        guard samples.count >= 2 else { return }

        // Clamp RSSI to a sensible mesh-radio band so the curve has
        // visible amplitude even when the signal is steady.
        let minDb = -120.0
        let maxDb = -40.0
        let range = maxDb - minDb
        let pad: CGFloat = 4
        let usableHeight = size.height - pad * 2
        let stepX = size.width / CGFloat(samples.count - 1)

        let points: [CGPoint] = samples.enumerated().map { i, s in
            let dbm = max(minDb, min(maxDb, Double(s)))
            let yNorm = 1.0 - (dbm - minDb) / range
            return CGPoint(
                x: CGFloat(i) * stepX,
                y: pad + CGFloat(yNorm) * usableHeight
            )
        }

        guard let first = points.first, let last = points.last else { return }

        if close {
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: first)
        } else {
            path.move(to: first)
        }

        // Smooth the curve with quadratic segments through midpoints —
        // gives the Flighty-style flowing aurora silhouette.
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
            if i == points.count - 1 {
                path.addLine(to: curr)
            }
        }

        if close {
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }
}

// MARK: - Link Status Pill — green/amber/red right-side header chip

@available(iOS 16.2, *)
struct LinkStatusPill: View {
    let status: String

    private var label: String {
        switch status {
        case "ok": return "LINK OK"
        case "stale": return "STALE"
        case "lost": return "LOST"
        default: return "IDLE"
        }
    }

    private var color: Color {
        switch status {
        case "ok": return SM.green
        case "stale": return SM.orange
        case "lost": return SM.red
        default: return SM.textTertiary
        }
    }

    var body: some View {
        Text(label)
            .font(SM.mono(9, weight: .heavy))
            .tracking(1.0)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(color.opacity(0.45), lineWidth: 0.6)
            )
    }
}

// MARK: - Hero Stat Cell — icon + mono value (battery / uptime / nodes)

@available(iOS 16.2, *)
struct HeroStat: View {
    let icon: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
            Text(value)
                .font(SM.mono(13, weight: .heavy))
                .foregroundColor(SM.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Time formatters (shared by Lock Screen and DI)

private func formatAge(_ sec: Int) -> String {
    if sec < 0 { return "—" }
    if sec == 0 { return "now" }
    if sec < 60 { return "\(sec)s ago" }
    if sec < 3600 { return "\(sec / 60)m ago" }
    if sec < 86_400 { return "\(sec / 3600)h ago" }
    return "\(sec / 86_400)d ago"
}

private func formatUptime(_ sec: Int) -> String {
    if sec <= 0 { return "—" }
    if sec < 3600 { return "\(sec / 60)m" }
    if sec < 86_400 {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
    let d = sec / 86_400
    let h = (sec % 86_400) / 3600
    return h == 0 ? "\(d)d" : "\(d)d \(h)h"
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
