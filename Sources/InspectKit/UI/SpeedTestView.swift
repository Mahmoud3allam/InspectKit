#if canImport(UIKit)
import SwiftUI

// MARK: - Local colour palette

private enum STC {
    static let bg         = Color(red: 0.051, green: 0.051, blue: 0.078)
    static let surface    = Color(red: 0.075, green: 0.075, blue: 0.118)
    static let arcBlue    = Color(red: 0.133, green: 0.400, blue: 1.000)
    static let arcCyan    = Color(red: 0.000, green: 0.800, blue: 1.000)
    static let text       = Color.white
    static let textSub    = Color.white.opacity(0.45)
    static let textFaint  = Color.white.opacity(0.25)
    static let accent     = Color(red: 0.133, green: 0.400, blue: 1.000)
}

// MARK: - Root view

struct SpeedTestView: View {

    @ObservedObject private var tester: InspectKitSpeedTester

    init() {
        _tester = ObservedObject(wrappedValue: InspectKitSpeedTester())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                speedometer
                metricsRow
                if !tester.realtimeSamples.isEmpty || tester.phase.isRunning {
                    bitrateChart
                }
                actionButton
                recentTestsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(STC.bg.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("Speed Test", displayMode: .inline)
        .colorScheme(.dark)
    }

    // MARK: - Speedometer

    private var speedometer: some View {
        ZStack {
            // Track arc (270°)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Active arc
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, 0.75 * gaugeProgress)))
                .stroke(
                    LinearGradient(colors: [STC.arcBlue, STC.arcCyan],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .shadow(color: STC.arcCyan.opacity(0.55), radius: 18)
                .animation(.easeOut(duration: 0.25), value: gaugeProgress)

            // Center content
            VStack(spacing: 4) {
                Text(speedLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(STC.textSub)
                    .kerning(1.5)

                Text(speedValue)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(STC.text)
                    .animation(.easeOut(duration: 0.2), value: speedValue)

                Text("MBPS")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(STC.arcCyan)
                    .kerning(2)

                if tester.phase.isRunning {
                    statusPill
                        .padding(.top, 6)
                }
            }
        }
        .frame(width: 220, height: 220)
        .padding(.top, 8)
    }

    private var gaugeProgress: Double {
        min(tester.currentSpeed / 1000.0, 1.0)
    }

    private var speedLabel: String {
        switch tester.phase {
        case .upload: return "UPLOAD SPEED"
        case .done:   return "DOWNLOAD SPEED"
        default:      return "DOWNLOAD SPEED"
        }
    }

    private var speedValue: String {
        let v = tester.currentSpeed
        if v == 0 { return "—" }
        return v >= 100
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(STC.arcCyan)
                .frame(width: 6, height: 6)
            Text(tester.phase.label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(STC.text)
                .kerning(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(STC.arcBlue.opacity(0.25))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(STC.arcBlue.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Metrics row

    private var metricsRow: some View {
        HStack(spacing: 10) {
            MetricTile(label: "PING",
                       value: tester.pingMS.map { String(format: "%.0f", $0) } ?? "—",
                       unit: "MS",
                       isActive: tester.phase == .ping)
            MetricTile(label: "JITTER",
                       value: tester.jitterMS.map { String(format: "%.0f", $0) } ?? "—",
                       unit: "MS",
                       isActive: tester.phase == .ping)
            MetricTile(label: "LOSS",
                       value: tester.lossPercent.map { String(format: "%.1f", $0) } ?? "—",
                       unit: "%",
                       isActive: false)
        }
    }

    // MARK: - Real-time bitrate chart

    private var bitrateChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("REAL-TIME BITRATE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(STC.textSub)
                    .kerning(1.2)
                Spacer()
                Text(stabilityLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isStable ? STC.arcCyan : Color.orange)
                    .kerning(1.2)
            }

            GeometryReader { geo in
                let samples = Array(tester.realtimeSamples.suffix(20))
                let maxVal  = max(samples.max() ?? 1, 1.0)
                let barW    = max((geo.size.width - CGFloat(samples.count - 1) * 4) / CGFloat(max(samples.count, 1)), 8)
                let chartH  = geo.size.height

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { _, val in
                        let ratio  = val / maxVal
                        let height = max(4, chartH * CGFloat(ratio))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(STC.arcBlue.opacity(0.4 + 0.6 * ratio))
                            .frame(width: barW, height: height)
                            .animation(.easeOut(duration: 0.2), value: height)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: chartH, alignment: .bottom)
            }
            .frame(height: 56)
        }
        .padding(14)
        .background(STC.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var isStable: Bool {
        let s = tester.realtimeSamples
        guard s.count > 2 else { return true }
        let avg = s.reduce(0, +) / Double(s.count)
        guard avg > 0 else { return true }
        let std = sqrt(s.map { pow($0 - avg, 2) }.reduce(0, +) / Double(s.count))
        return (std / avg) < 0.25
    }

    private var stabilityLabel: String { isStable ? "STABLE" : "VARIABLE" }

    // MARK: - Action button

    private var actionButton: some View {
        Button(action: tester.phase.isRunning ? tester.cancel : tester.start) {
            HStack(spacing: 8) {
                if tester.phase.isRunning {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(tester.phase.isRunning ? "CANCEL" : "RUN SPEED TEST")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .kerning(1.2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tester.phase.isRunning ? Color.red.opacity(0.7) : STC.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Recent tests

    private var recentTestsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RECENT TESTS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(STC.textSub)
                    .kerning(1.2)
                Spacer()
                if !tester.history.isEmpty {
                    Button("CLEAR ALL") { tester.clearHistory() }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(STC.accent)
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.bottom, 12)

            if tester.history.isEmpty {
                Text("No recent tests")
                    .font(.system(size: 13))
                    .foregroundColor(STC.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 1) {
                    ForEach(tester.history) { record in
                        HistoryRow(record: record)
                        if record.id != tester.history.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(STC.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - MetricTile

private struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(STC.textSub)
                .kerning(1.2)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? STC.arcCyan : STC.text)
                Text(unit)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(STC.textSub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(STC.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? STC.arcBlue.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - HistoryRow

private struct HistoryRow: View {
    let record: SpeedTestRecord

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(formattedDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(STC.text)
                Text("\(record.deviceName) • \(record.connectionType)")
                    .font(.system(size: 11))
                    .foregroundColor(STC.textSub)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 16) {
                speedColumn(label: "DOWN", value: record.downloadMbps)
                speedColumn(label: "UP",   value: record.uploadMbps)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(STC.textFaint)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func speedColumn(label: String, value: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(STC.textSub)
                .kerning(1)
            Text(value >= 100
                 ? String(format: "%.0f", value)
                 : String(format: "%.1f", value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(STC.text)
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f.string(from: record.date)
    }
}

#endif // canImport(UIKit)
