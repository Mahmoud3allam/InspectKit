import SwiftUI

struct SpeedTestView: View {

    // @StateObject is iOS 14+; initialising via ObservedObject wrappedValue in
    // init() is the iOS 13-compatible equivalent for a view-owned object.
    @ObservedObject private var tester: InspectKitSpeedTester

    init() {
        _tester = ObservedObject(wrappedValue: InspectKitSpeedTester())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                resultCards
                if tester.phase != .idle { progressBars }
                statusRow
                actionButton
                Spacer(minLength: 0)
                footer
            }
            .padding(16)
        }
        .background(NIColor.bg.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("Speed Test", displayMode: .inline)
    }

    // MARK: - Result cards

    private var resultCards: some View {
        HStack(spacing: 10) {
            MetricCard(
                title: "PING",
                value: tester.pingMS.map { String(format: "%.0f ms", $0) },
                unit: "ms",
                color: pingColor,
                isActive: tester.phase == .ping
            )
            MetricCard(
                title: "DOWNLOAD",
                value: tester.downloadMbps.map { formatMbps($0) },
                unit: "Mb/s",
                color: speedColor(tester.downloadMbps),
                isActive: tester.phase == .download
            )
            MetricCard(
                title: "UPLOAD",
                value: tester.uploadMbps.map { formatMbps($0) },
                unit: "Mb/s",
                color: speedColor(tester.uploadMbps),
                isActive: tester.phase == .upload
            )
        }
    }

    // MARK: - Progress bars

    private var progressBars: some View {
        VStack(spacing: 10) {
            if tester.phase == .download || tester.downloadMbps != nil {
                ProgressRow(label: "Download",
                            progress: tester.downloadProgress,
                            color: speedColor(tester.downloadMbps))
            }
            if tester.phase == .upload || tester.uploadMbps != nil {
                ProgressRow(label: "Upload",
                            progress: tester.uploadProgress,
                            color: speedColor(tester.uploadMbps))
            }
        }
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: 8) {
            if tester.phase.isRunning {
                NIActivityIndicator()
                    .frame(width: 16, height: 16)
            }
            Text(tester.phase.label)
                .font(NIFont.footnoteSemibold)
                .foregroundColor(statusLabelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Button

    private var actionButton: some View {
        Button(action: tester.phase.isRunning ? tester.cancel : tester.start) {
            Text(tester.phase.isRunning ? "Cancel" : "Start Test")
                .font(NIFont.footnoteSemibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(tester.phase.isRunning ? NIColor.failure : NIColor.accent)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Powered by Cloudflare · speed.cloudflare.com")
            .font(NIFont.monoSmall)
            .foregroundColor(NIColor.textFaint)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private func formatMbps(_ v: Double) -> String {
        v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private var pingColor: Color {
        guard let ms = tester.pingMS else { return NIColor.textFaint }
        if ms < 50  { return NIColor.success }
        if ms < 100 { return NIColor.warning }
        return NIColor.failure
    }

    private func speedColor(_ mbps: Double?) -> Color {
        guard let v = mbps else { return NIColor.textFaint }
        if v >= 20 { return NIColor.success }
        if v >= 5  { return NIColor.warning }
        return NIColor.failure
    }

    private var statusLabelColor: Color {
        if case .failed = tester.phase { return NIColor.failure }
        if tester.phase == .done        { return NIColor.success }
        return NIColor.textMuted
    }
}

// MARK: - MetricCard

private struct MetricCard: View {
    let title: String
    let value: String?
    let unit: String
    let color: Color
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(NIColor.textMuted)

            if let value {
                Text(value)
                    .font(NIFont.title3Semibold)
                    .foregroundColor(color)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } else if isActive {
                NIActivityIndicator()
                    .frame(height: 24)
            } else {
                Text("—")
                    .font(NIFont.title3Semibold)
                    .foregroundColor(NIColor.textFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - ProgressRow

private struct ProgressRow: View {
    let label: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(NIColor.textMuted)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NIColor.surfaceElevated)
                        .frame(height: 8)
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * progress, 0), height: 8)
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
