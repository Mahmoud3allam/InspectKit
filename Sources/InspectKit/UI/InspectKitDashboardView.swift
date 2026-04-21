#if canImport(UIKit)
import SwiftUI

public struct InspectKitDashboardView: View {
    @ObservedObject var store: InspectKitStore
    @State private var query: String = ""
    @State private var stateFilter: InspectKitStore.StateFilter = .all
    @State private var methodFilter: Set<HTTPMethod> = []

    public var onDismiss: (() -> Void)?

    public init(store: InspectKitStore? = nil, onDismiss: (() -> Void)? = nil) {
        self.store = store ?? InspectKit.shared.store
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                summarySection
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                controls
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                Divider().overlay(NIColor.divider).padding(.top, 10)
                ScrollView {
                    NetworkRequestListView(store: store, records: filtered)
                        .padding(.top, 10)
                }
                .background(NIColor.bg)
            }
            // ignoresSafeArea() is iOS 14+; edgesIgnoringSafeArea is iOS 13+
            .background(NIColor.bg.edgesIgnoringSafeArea(.all))
            // navigationTitle + navigationBarTitleDisplayMode are iOS 14+
            .navigationBarTitle("Network", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: { onDismiss?() }) {
                    Image(systemName: "xmark")
                        .font(NIFont.footnoteSemibold)
                },
                trailing: HStack(spacing: 16) {
                    NavigationLink(destination: SpeedTestView()) {
                        Image(systemName: "bolt.fill")
                    }
                    // Button(role:) is iOS 15+; plain Button is iOS 13+
                    Button(action: { store.clear() }) {
                        Image(systemName: "trash")
                    }
                    .disabled(store.records.isEmpty)
                }
            )
        }
        // .stack shorthand is iOS 15+; StackNavigationViewStyle() is iOS 13+
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }

    private var filtered: [NetworkRequestRecord] {
        store.filtered(query: query, stateFilter: stateFilter, methodFilter: methodFilter)
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: 8) {
            SummaryCard(title: "Total", value: "\(store.totalCount)", tint: NIColor.accent)
            SummaryCard(title: "Failed", value: "\(store.failureCount)", tint: NIColor.failure)
            SummaryCard(title: "Active", value: "\(store.activeCount)", tint: NIColor.warning)
            SummaryCard(title: "Avg", value: store.averageDurationMS.formattedMilliseconds(), tint: NIColor.success)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            searchField

            Picker("", selection: $stateFilter) {
                ForEach(InspectKitStore.StateFilter.allCases) { f in
                    Text(f.title).tag(f)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([HTTPMethod.GET, .POST, .PUT, .PATCH, .DELETE], id: \.rawValue) { m in
                        MethodChip(method: m, isOn: methodFilter.contains(m)) {
                            if methodFilter.contains(m) { methodFilter.remove(m) } else { methodFilter.insert(m) }
                        }
                    }
                    if !methodFilter.isEmpty {
                        Button("Reset") { methodFilter.removeAll() }
                            .font(.footnote)
                            .foregroundColor(NIColor.accent)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(NIColor.textMuted)
            TextField("Search path, host, or status", text: $query)
                .textFieldStyle(PlainTextFieldStyle())
                // autocorrectionDisabled() is iOS 15+; disableAutocorrection is iOS 13+
                .disableAutocorrection(true)
                .autocapitalization(.none)
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(NIColor.textFaint)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

}

private struct MethodChip: View {
    let method: HTTPMethod
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(method.rawValue)
                .font(NIFont.badge)
                .foregroundColor(isOn ? .white : NIColor.method(method))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isOn ? NIColor.method(method) : NIColor.method(method).opacity(0.18))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#endif // canImport(UIKit)
