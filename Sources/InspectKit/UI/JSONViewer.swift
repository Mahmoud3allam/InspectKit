import SwiftUI

struct JSONViewer: View {
    let capturedBody: CapturedBody

    @State private var expanded = false

    var body: some View {
        let rendered = PrettyPrint.render(body: capturedBody)
        let preview = rendered.text
        let isLarge = preview.count > 2000

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(rendered.isJSON ? "JSON" : (capturedBody.kind == .text ? "TEXT" : "BODY"))
                    .font(NIFont.badge)
                    .foregroundColor(NIColor.accent)
                Text(ByteCountFormatter.string(fromBytes: capturedBody.byteCount))
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textMuted)
                if capturedBody.isTruncated {
                    Text("TRUNCATED")
                        .font(NIFont.badge)
                        .foregroundColor(NIColor.warning)
                }
                Spacer()
                CopyButton(text: preview)
            }

            if preview.isEmpty {
                Text("Empty body")
                    .font(.footnote)
                    .foregroundColor(NIColor.textMuted)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    Text(preview)
                        .font(NIFont.mono)
                        .foregroundColor(NIColor.text)
                        .enableTextSelection()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: (isLarge && !expanded) ? 260 : .infinity)
                .background(NIColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if isLarge {
                    Button(expanded ? "Collapse" : "Expand") {
                        withAnimation { expanded.toggle() }
                    }
                    .font(NIFont.footnoteSemibold)
                    .foregroundColor(NIColor.accent)
                }
            }
        }
    }
}

struct BinaryMetadataCard: View {
    let capturedBody: CapturedBody

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: capturedBody.kind == .image ? "photo" : "doc.fill")
                .foregroundColor(NIColor.accent)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(capturedBody.contentType ?? "binary/unknown")
                    .font(NIFont.footnoteSemibold)
                Text("\(ByteCountFormatter.string(fromBytes: capturedBody.byteCount))\(capturedBody.isTruncated ? " · truncated" : "")")
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textMuted)
            }
            Spacer()
        }
        .padding(12)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
