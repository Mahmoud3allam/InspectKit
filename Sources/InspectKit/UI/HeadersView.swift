#if canImport(UIKit)
import SwiftUI

struct HeadersView: View {
    let title: String
    let headers: [String: String]
    let redactor: InspectKitRedactor

    private var sortedKeys: [String] { headers.keys.sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(NIFont.sectionTitle)
                    .foregroundColor(NIColor.textMuted)
                Spacer()
                if !headers.isEmpty {
                    CopyButton(text: headers.map { "\($0.key): \(redactor.redactHeaders(headers)[$0.key] ?? "")" }
                               .sorted().joined(separator: "\n"))
                }
            }
            if headers.isEmpty {
                Text("No headers")
                    .font(.footnote)
                    .foregroundColor(NIColor.textFaint)
                    .padding(.vertical, 4)
            } else {
                let redacted = redactor.redactHeaders(headers)
                VStack(spacing: 0) {
                    ForEach(sortedKeys, id: \.self) { key in
                        HeaderRow(key: key, value: redacted[key] ?? "",
                                  isRedacted: redacted[key] != headers[key])
                        if key != sortedKeys.last { Divider().overlay(NIColor.divider) }
                    }
                }
                .background(NIColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct HeaderRow: View {
    let key: String
    let value: String
    let isRedacted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(NIFont.monoSemibold)
                .foregroundColor(NIColor.text)
                .frame(maxWidth: 140, alignment: .leading)
                .lineLimit(3)
            Text(value)
                .font(NIFont.mono)
                .foregroundColor(isRedacted ? NIColor.warning : NIColor.textMuted)
                .enableTextSelection()
                .frame(maxWidth: .infinity, alignment: .leading)
            CopyButton(text: "\(key): \(value)", compact: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

#endif // canImport(UIKit)
