#if canImport(UIKit)
import SwiftUI
import InspectKitCore

struct ScenarioPickerView: View {
    @ObservedObject var store: MockStore
    var onDismiss: (() -> Void)?

    @State private var showAddScenario = false
    @State private var newScenarioName = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if store.scenarios.isEmpty {
                    Spacer()
                    Text("No scenarios yet")
                        .foregroundColor(NIColor.textMuted)
                    Text("Group rules into a scenario to test specific app states.")
                        .font(.footnote)
                        .foregroundColor(NIColor.textFaint)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            Button(action: { store.deactivateAllScenarios() }) {
                                HStack {
                                    Image(systemName: store.scenarios.allSatisfy({ !$0.isActive })
                                          ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(store.scenarios.allSatisfy({ !$0.isActive })
                                                         ? NIColor.success : NIColor.textFaint)
                                    Text("No scenario (all enabled rules)")
                                        .foregroundColor(NIColor.text)
                                    Spacer()
                                }
                                .padding(10)
                                .background(NIColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())

                            ForEach(store.scenarios) { scenario in
                                ScenarioRow(scenario: scenario,
                                            allRules: store.rules,
                                            onActivate: { store.activateScenario(id: scenario.id) },
                                            onDelete: { store.removeScenario(id: scenario.id) })
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(NIColor.bg)
                }
            }
            .background(NIColor.bg.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Scenarios", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Done") { onDismiss?() },
                trailing: Button(action: { showAddScenario = true }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showAddScenario) {
                NewScenarioSheet(store: store, onDismiss: { showAddScenario = false })
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}

private struct ScenarioRow: View {
    let scenario: MockScenario
    let allRules: [MockRule]
    let onActivate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onActivate) {
                Image(systemName: scenario.isActive ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(scenario.isActive ? NIColor.success : NIColor.textFaint)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(scenario.name)
                    .font(NIFont.footnoteSemibold)
                    .foregroundColor(NIColor.text)
                Text("\(scenario.ruleIDs.count) rule(s)")
                    .font(NIFont.monoSmall)
                    .foregroundColor(NIColor.textFaint)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(NIColor.failure)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(10)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct NewScenarioSheet: View {
    @ObservedObject var store: MockStore
    var onDismiss: (() -> Void)?

    @State private var name = ""
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("e.g. Login errors", text: $name)
                }
                Section(header: Text("Rules to include")) {
                    ForEach(store.rules) { rule in
                        Button(action: {
                            if selectedIDs.contains(rule.id) { selectedIDs.remove(rule.id) }
                            else { selectedIDs.insert(rule.id) }
                        }) {
                            HStack {
                                Text(rule.name).foregroundColor(.primary)
                                Spacer()
                                if selectedIDs.contains(rule.id) {
                                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("New Scenario", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { onDismiss?() },
                trailing: Button("Save") {
                    let scenario = MockScenario(name: name.isEmpty ? "Untitled" : name,
                                               ruleIDs: Array(selectedIDs))
                    store.addScenario(scenario)
                    onDismiss?()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#endif // canImport(UIKit)
