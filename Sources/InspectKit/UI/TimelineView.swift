import SwiftUI

struct TimelineView: View {
    let record: NetworkRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let d = record.durationMS {
                HStack(alignment: .firstTextBaseline) {
                    Text("Total")
                        .font(NIFont.sectionTitle)
                        .foregroundColor(NIColor.textMuted)
                    Spacer()
                    Text(d.formattedMilliseconds())
                        .font(NIFont.title3Semibold)
                        .foregroundColor(NIColor.accent)
                }
            }

            if let metrics = record.metrics, let tx = metrics.transactions.first {
                transportRow(for: tx)
                timelineRows(for: tx)
            } else {
                emptyMetrics
            }
        }
    }

    private func transportRow(for t: CapturedTransactionMetric) -> some View {
        HStack(spacing: 8) {
            if let proto = t.networkProtocolName {
                tag(proto.uppercased(), color: NIColor.accent)
            }
            tag(t.isReusedConnection ? "REUSED" : "NEW CONN", color: t.isReusedConnection ? NIColor.success : NIColor.warning)
            tag(t.resourceFetchType.uppercased(), color: NIColor.textMuted)
            if t.isProxyConnection { tag("PROXY", color: NIColor.warning) }
            Spacer()
        }
    }

    private func timelineRows(for t: CapturedTransactionMetric) -> some View {
        let phases: [(String, Double?)] = [
            ("DNS", t.dnsDurationMS),
            ("Connect", t.connectDurationMS),
            ("TLS", t.tlsDurationMS),
            ("Request", t.requestDurationMS),
            ("First byte", firstByteLatency(t)),
            ("Response", t.responseDurationMS)
        ]
        let maxMs = max(phases.compactMap { $0.1 }.max() ?? 1, 1)

        return VStack(spacing: 6) {
            ForEach(phases, id: \.0) { item in
                phaseRow(label: item.0, ms: item.1, scale: maxMs)
            }
        }
        .padding(10)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func phaseRow(label: String, ms: Double?, scale: Double) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(NIFont.mono)
                .frame(width: 86, alignment: .leading)
                .foregroundColor(NIColor.textMuted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(NIColor.surfaceElevated)
                        .frame(height: 8)
                    if let ms {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(NIColor.accent)
                            .frame(width: max(4, CGFloat(ms / scale) * geo.size.width), height: 8)
                    }
                }
            }
            .frame(height: 8)
            Text(ms?.formattedMilliseconds() ?? "—")
                .font(NIFont.monoSmall)
                .foregroundColor(ms == nil ? NIColor.textFaint : NIColor.text)
                .frame(width: 72, alignment: .trailing)
        }
    }

    private func firstByteLatency(_ t: CapturedTransactionMetric) -> Double? {
        guard let rs = t.requestStart, let rr = t.responseStart else { return nil }
        return rr.timeIntervalSince(rs) * 1000
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(NIFont.badge)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var emptyMetrics: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundColor(NIColor.textFaint)
            Text("No metrics available yet")
                .font(.footnote)
                .foregroundColor(NIColor.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
