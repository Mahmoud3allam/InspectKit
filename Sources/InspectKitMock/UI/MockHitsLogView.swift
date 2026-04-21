#if canImport(UIKit)
import SwiftUI
import InspectKitCore

struct MockHitsLogView: View {
    @ObservedObject var store: MockStore

    var body: some View {
        VStack(spacing: 0) {
            if store.hits.isEmpty {
                Spacer()
                Text("No hits yet")
                    .foregroundColor(NIColor.textMuted)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(store.hits) { hit in
                            MockHitRow(hit: hit)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(NIColor.bg.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("Hit Log", displayMode: .inline)
        .navigationBarItems(trailing: Button("Clear") { store.clearHits() }
            .foregroundColor(NIColor.accent))
    }
}

struct MockHitRow: View {
    let hit: MockHit

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(hit.ruleName)
                    .font(NIFont.footnoteSemibold)
                    .foregroundColor(NIColor.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(hit.method.rawValue)
                        .font(NIFont.badge)
                        .foregroundColor(NIColor.method(hit.method))
                    Text(hit.url?.path ?? hit.url?.absoluteString ?? "-")
                        .font(NIFont.monoSmall)
                        .foregroundColor(NIColor.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if let code = hit.statusCode {
                    Text("\(code)")
                        .font(NIFont.badge)
                        .foregroundColor(NIColor.statusColor(code))
                } else {
                    Text("ERR")
                        .font(NIFont.badge)
                        .foregroundColor(NIColor.failure)
                }
                Text(DateFormatter.networkInspectorTime.string(from: hit.date))
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textFaint)
            }
        }
        .padding(10)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#endif // canImport(UIKit)
