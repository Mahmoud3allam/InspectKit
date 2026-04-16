import SwiftUI

struct NetworkRequestListView: View {
    @ObservedObject var store: InspectKitStore
    let records: [NetworkRequestRecord]

    var body: some View {
        if records.isEmpty {
            EmptyStateView()
        } else {
            VStack(spacing: 6) {
                ForEach(records) { record in
                    NavigationLink(destination: NetworkRequestDetailView(store: store, recordID: record.id)) {
                        RequestRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
    }
}

private struct RequestRow: View {
    let record: NetworkRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                MethodBadge(method: record.method)
                StatusBadge(code: record.statusCode,
                            inProgress: record.state == .inProgress,
                            failed: record.isFailure)
                Spacer()
                Text(DateFormatter.networkInspectorTime.string(from: record.startDate))
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textFaint)
            }

            Text(record.displayEndpoint)
                .font(NIFont.footnoteSemibold)
                .foregroundColor(NIColor.text)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let host = record.host {
                    Text(host)
                        .font(NIFont.monoSmall)
                        .foregroundColor(NIColor.textMuted)
                        .lineLimit(1)
                }
                Spacer()
                // Label(_, systemImage:) + labelStyle(.titleAndIcon) are iOS 14+
                if let d = record.durationMS {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                        Text(d.formattedMilliseconds())
                    }
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textMuted)
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(sizeSummary)
                }
                .font(NIFont.monoSmall)
                .foregroundColor(NIColor.textMuted)
            }
        }
        .padding(10)
        .background(NIColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(record.isFailure ? NIColor.failure.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var sizeSummary: String {
        let req = ByteCountFormatter.string(fromBytes: record.requestBody.byteCount)
        let resp = ByteCountFormatter.string(fromBytes: record.responseBody.byteCount)
        return "\(req) / \(resp)"
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 60)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundColor(NIColor.textFaint)
            Text("No requests captured yet")
                .font(.headline)
                .foregroundColor(NIColor.textMuted)
            Text("Fire off a network request and it'll appear here in real time.")
                .font(.footnote)
                .foregroundColor(NIColor.textFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
