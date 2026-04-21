#if canImport(UIKit)
import SwiftUI
import InspectKitCore

struct MockRuleListView: View {
    @ObservedObject var store: MockStore
    @State private var editingRule: MockRule?

    var body: some View {
        VStack(spacing: 6) {
            if store.rules.isEmpty {
                emptyState
            } else {
                ForEach(store.rules) { rule in
                    MockRuleRow(rule: rule,
                                onToggle: { store.setEnabled(id: rule.id, enabled: !rule.isEnabled) },
                                onEdit:   { editingRule = rule },
                                onDelete: { store.remove(id: rule.id) })
                }
            }
        }
        .padding(.horizontal, 12)
        .sheet(item: $editingRule) { rule in
            MockRuleEditorView(store: store, rule: rule, onDismiss: { editingRule = nil })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40))
                .foregroundColor(NIColor.textFaint)
            Text("No mock rules")
                .font(.headline)
                .foregroundColor(NIColor.textMuted)
            Text("Tap + to create a rule that intercepts a request and returns a fake response.")
                .font(.footnote)
                .foregroundColor(NIColor.textFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private struct MockRuleRow: View {
    let rule: MockRule
    let onToggle: () -> Void
    let onEdit:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: rule.isEnabled ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(rule.isEnabled ? NIColor.success : NIColor.textFaint)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name)
                    .font(NIFont.footnoteSemibold)
                    .foregroundColor(NIColor.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let method = rule.matcher.method {
                        Text(method.rawValue)
                            .font(NIFont.badge)
                            .foregroundColor(NIColor.method(method))
                    }
                    statusLabel
                    if rule.hitCount > 0 {
                        Text("\(rule.hitCount) hits")
                            .font(NIFont.monoSmall)
                            .foregroundColor(NIColor.textFaint)
                    }
                    if rule.delay > 0 {
                        Text("\(String(format: "%.1f", rule.delay))s delay")
                            .font(NIFont.monoSmall)
                            .foregroundColor(NIColor.warning)
                    }
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(NIColor.accent)
            }
            .buttonStyle(PlainButtonStyle())

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

    @ViewBuilder
    private var statusLabel: some View {
        switch rule.response.kind {
        case let .ok(code, _, _):
            Text("\(code)")
                .font(NIFont.badge)
                .foregroundColor(NIColor.statusColor(code))
        case .failure:
            Text("ERR")
                .font(NIFont.badge)
                .foregroundColor(NIColor.failure)
        }
    }
}

#endif // canImport(UIKit)
