#if canImport(UIKit)
import SwiftUI

struct NetworkRequestDetailView: View {
    @ObservedObject var store: InspectKitStore
    let recordID: UUID

    @State private var selectedTab: Tab = .overview
    @State private var showSensitive: Bool = false

    private var activeRedactor: InspectKitRedactor {
        showSensitive ? .identity : InspectKit.shared.redactor
    }

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case request = "Request"
        case response = "Response"
        case headers = "Headers"
        case metrics = "Metrics"
        case curl = "cURL"
        var id: String { rawValue }
    }

    private var record: NetworkRequestRecord? {
        store.records.first { $0.id == recordID }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let record = record {
                DetailHeader(record: record, showSensitive: $showSensitive)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                TabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                Divider().overlay(NIColor.divider).padding(.top, 8)
                ScrollView {
                    content(for: record)
                        .padding(16)
                }
            } else {
                Spacer()
                Text("Request no longer available")
                    .foregroundColor(NIColor.textMuted)
                Spacer()
            }
        }
        .background(NIColor.bg)
        // navigationTitle is iOS 14+; navigationBarTitle is iOS 13+
        .navigationBarTitle("Request", displayMode: .inline)
    }

    @ViewBuilder
    private func content(for r: NetworkRequestRecord) -> some View {
        switch selectedTab {
        case .overview: OverviewTab(record: r)
        case .request: RequestTab(record: r, redactor: activeRedactor)
        case .response: ResponseTab(record: r, redactor: activeRedactor)
        case .headers: HeadersTab(record: r, redactor: activeRedactor)
        case .metrics: TimelineView(record: r)
        case .curl: CurlPreviewView(record: r,
                                    exporter: InspectKit.shared.exporter,
                                    allowsExport: InspectKit.shared.configuration.allowsExport)
        }
    }
}

// MARK: - Header & Tab bar

private struct DetailHeader: View {
    let record: NetworkRequestRecord
    @Binding var showSensitive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MethodBadge(method: record.method)
                StatusBadge(code: record.statusCode,
                            inProgress: record.state == .inProgress,
                            failed: record.isFailure)
                if let env = record.environment { EnvBadge(text: env) }
                Spacer()
                if let d = record.durationMS {
                    Text(d.formattedMilliseconds())
                        .font(NIFont.monoSemibold)
                        .foregroundColor(NIColor.text)
                }
                Button {
                    showSensitive.toggle()
                } label: {
                    Image(systemName: showSensitive ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(showSensitive ? NIColor.accent : NIColor.textMuted)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Text(record.urlString)
                .font(NIFont.mono)
                .foregroundColor(NIColor.textMuted)
                .lineLimit(3)
                // textSelection is iOS 15+; enableTextSelection() wraps availability
                .enableTextSelection()
        }
    }
}

private struct TabBar: View {
    @Binding var selected: NetworkRequestDetailView.Tab

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(NetworkRequestDetailView.Tab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { selected = tab }
                    }) {
                        Text(tab.rawValue)
                            // .footnote.weight(.semibold) uses Font.weight which is iOS 14+
                            .font(NIFont.footnoteSemibold)
                            .foregroundColor(selected == tab ? .white : NIColor.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected == tab ? NIColor.accent : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Tabs

private struct OverviewTab: View {
    let record: NetworkRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let err = record.error {
                ErrorCard(message: err.localizedDescription,
                          detail: err.domain.map { "\($0) · \(err.code ?? 0)" })
            }

            KeyValueCard(pairs: [
                ("URL", record.urlString),
                ("Method", record.method.rawValue),
                ("Status", record.statusCode.map(String.init) ?? "—"),
                ("Host", record.host ?? "—"),
                ("Path", record.path.isEmpty ? "/" : record.path),
                ("Start", DateFormatter.networkInspectorFull.string(from: record.startDate)),
                ("Duration", record.durationMS?.formattedMilliseconds() ?? "—"),
                ("Request size", ByteCountFormatter.string(fromBytes: record.requestBody.byteCount)),
                ("Response size", ByteCountFormatter.string(fromBytes: record.responseBody.byteCount)),
                ("Environment", record.environment ?? "—")
            ])

            if !record.queryItems.isEmpty {
                KeyValueCard(title: "Query",
                             pairs: record.queryItems.sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
            }
        }
    }
}

private struct RequestTab: View {
    let record: NetworkRequestRecord
    let redactor: InspectKitRedactor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeadersView(title: "Request Headers", headers: record.requestHeaders, redactor: redactor)
            sectionTitle("Body")
            bodyView(for: redactor.redactBody(record.requestBody))
        }
    }
}

private struct ResponseTab: View {
    let record: NetworkRequestRecord
    let redactor: InspectKitRedactor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeadersView(title: "Response Headers", headers: record.responseHeaders, redactor: redactor)
            sectionTitle("Body")
            bodyView(for: redactor.redactBody(record.responseBody))
        }
    }
}

private struct HeadersTab: View {
    let record: NetworkRequestRecord
    let redactor: InspectKitRedactor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeadersView(title: "Request Headers", headers: record.requestHeaders, redactor: redactor)
            HeadersView(title: "Response Headers", headers: record.responseHeaders, redactor: redactor)
        }
    }
}

// MARK: - Shared subviews

@ViewBuilder
private func bodyView(for body: CapturedBody) -> some View {
    if body.byteCount == 0 {
        EmptyBodyCard()
    } else if body.kind == .image || body.kind == .binary || body.kind == .multipart {
        BinaryMetadataCard(capturedBody: body)
    } else {
        JSONViewer(capturedBody: body)
    }
}

private func sectionTitle(_ text: String) -> some View {
    Text(text.uppercased())
        .font(NIFont.sectionTitle)
        .foregroundColor(NIColor.textMuted)
}

private struct EmptyBodyCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundColor(NIColor.textFaint)
            Text("No body")
                .font(.footnote)
                .foregroundColor(NIColor.textMuted)
            Spacer()
        }
        .padding(12)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct KeyValueCard: View {
    var title: String? = nil
    let pairs: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title.uppercased())
                    .font(NIFont.sectionTitle)
                    .foregroundColor(NIColor.textMuted)
            }
            VStack(spacing: 0) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                    HStack(alignment: .top, spacing: 10) {
                        Text(pair.0)
                            // NIFont.mono.weight(.semibold) uses Font.weight which is iOS 14+
                            .font(NIFont.monoSemibold)
                            .foregroundColor(NIColor.textMuted)
                            .frame(width: 110, alignment: .leading)
                        Text(pair.1)
                            .font(NIFont.mono)
                            .foregroundColor(NIColor.text)
                            .enableTextSelection()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    if idx != pairs.count - 1 { Divider().overlay(NIColor.divider) }
                }
            }
            .background(NIColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct ErrorCard: View {
    let message: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(NIColor.failure)
                Text("Request failed")
                    .font(.subheadline)
                    .foregroundColor(NIColor.failure)
            }
            Text(message)
                .font(.footnote)
                .foregroundColor(NIColor.text)
            if let detail = detail {
                Text(detail)
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textMuted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NIColor.failure.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(NIColor.failure.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#endif // canImport(UIKit)
