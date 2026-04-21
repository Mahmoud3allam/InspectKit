#if canImport(UIKit)
import SwiftUI
import InspectKitCore

public struct MockDashboardView: View {
    @ObservedObject var store: MockStore
    public var onDismiss: (() -> Void)?

    public init(store: MockStore? = nil, onDismiss: (() -> Void)? = nil) {
        self.store = store ?? InspectKitMock.shared.store
        self.onDismiss = onDismiss
    }

    @State private var showAddRule = false
    @State private var showScenarios = false
    @State private var showHitsLog = false

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                summaryBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                Divider().overlay(NIColor.divider)
                ScrollView {
                    VStack(spacing: 0) {
                        MockRuleListView(store: store)
                            .padding(.top, 10)
                        if !store.hits.isEmpty {
                            hitsSection
                                .padding(.top, 14)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(NIColor.bg)
            }
            .background(NIColor.bg.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Mocks", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: { onDismiss?() }) {
                    Image(systemName: "xmark")
                        .font(NIFont.footnoteSemibold)
                },
                trailing: HStack(spacing: 16) {
                    Button(action: { showScenarios = true }) {
                        Image(systemName: "film.stack")
                    }
                    Button(action: { showAddRule = true }) {
                        Image(systemName: "plus")
                    }
                }
            )
            .sheet(isPresented: $showAddRule) {
                MockRuleEditorView(store: store, rule: nil, onDismiss: { showAddRule = false })
            }
            .sheet(isPresented: $showScenarios) {
                ScenarioPickerView(store: store, onDismiss: { showScenarios = false })
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }

    private var summaryBar: some View {
        HStack(spacing: 8) {
            MockSummaryCard(title: "Rules", value: "\(store.rules.count)", tint: NIColor.accent)
            MockSummaryCard(title: "Enabled", value: "\(store.rules.filter(\.isEnabled).count)", tint: NIColor.success)
            MockSummaryCard(title: "Hits", value: "\(store.hits.count)", tint: NIColor.accentCyan)
            if let active = store.scenarios.first(where: { $0.isActive }) {
                MockSummaryCard(title: "Scenario", value: active.name, tint: NIColor.warning)
            }
        }
    }

    private var hitsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent Hits")
                    .font(NIFont.sectionTitle)
                    .foregroundColor(NIColor.textMuted)
                    .padding(.horizontal, 12)
                Spacer()
                Button("Clear") { store.clearHits() }
                    .font(.footnote)
                    .foregroundColor(NIColor.accent)
                    .padding(.horizontal, 12)
            }
            ForEach(store.hits.prefix(5)) { hit in
                MockHitRow(hit: hit)
                    .padding(.horizontal, 12)
            }
            if store.hits.count > 5 {
                NavigationLink(destination: MockHitsLogView(store: store)) {
                    Text("See all \(store.hits.count) hits →")
                        .font(.footnote)
                        .foregroundColor(NIColor.accent)
                        .padding(.horizontal, 12)
                }
            }
        }
    }
}

private struct MockSummaryCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(NIFont.title3Semibold)
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(NIFont.monoSmall)
                .foregroundColor(NIColor.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#endif // canImport(UIKit)
