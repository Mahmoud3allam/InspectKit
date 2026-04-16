import SwiftUI
import UIKit

struct CurlPreviewView: View {
    let record: NetworkRequestRecord
    let exporter: InspectKitExporter
    let allowsExport: Bool

    @State private var showShare = false

    private var curlText: String {
        exporter.curl(for: record, redacted: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("cURL")
                    .font(NIFont.sectionTitle)
                    .foregroundColor(NIColor.textMuted)
                Spacer()
                CopyButton(text: curlText)
                if allowsExport {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(NIColor.accent)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            ScrollView([.horizontal, .vertical]) {
                Text(curlText)
                    .font(NIFont.mono)
                    .enableTextSelection()
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 360)
            .background(NIColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [curlText])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
