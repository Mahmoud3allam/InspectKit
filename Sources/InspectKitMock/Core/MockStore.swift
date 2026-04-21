import Foundation
import Combine
import InspectKitCore

@MainActor
public final class MockStore: ObservableObject {
    @Published public private(set) var rules:     [MockRule]     = []
    @Published public private(set) var scenarios: [MockScenario] = []
    @Published public private(set) var hits:      [MockHit]      = []

    private let persistence: MockPersistence
    private let maxHits = 100

    init(persistence: MockPersistence) {
        self.persistence = persistence
        self.rules     = persistence.loadRules()
        self.scenarios = persistence.loadScenarios()
        // Don't call pushToMatcher() here — InspectKitMock.shared isn't ready yet.
        // start() performs the initial push after shared is fully initialised.
    }

    /// Called by InspectKitMock.start() to populate RuleMatcher with the initial snapshot.
    func initialPush(logToInspectKit: Bool) {
        let activeScenario = scenarios.first(where: { $0.isActive })
        RuleMatcher.shared.update(rules: rules,
                                  scenarioRuleIDs: activeScenario?.ruleIDs,
                                  logToInspectKit: logToInspectKit)
    }

    // MARK: - Rule mutations

    public func add(_ rule: MockRule) {
        rules.append(rule)
        persistence.saveRules(rules)
        pushToMatcher()
    }

    public func update(_ rule: MockRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var updated = rules
        updated[idx] = rule
        rules = updated
        persistence.saveRules(rules)
        pushToMatcher()
    }

    public func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        persistence.saveRules(rules)
        pushToMatcher()
    }

    public func setEnabled(id: UUID, enabled: Bool) {
        guard let idx = rules.firstIndex(where: { $0.id == id }) else { return }
        var updated = rules
        updated[idx].isEnabled = enabled
        rules = updated
        persistence.saveRules(rules)
        pushToMatcher()
    }

    // MARK: - Scenario mutations

    public func addScenario(_ scenario: MockScenario) {
        scenarios.append(scenario)
        persistence.saveScenarios(scenarios)
        pushToMatcher()
    }

    public func updateScenario(_ scenario: MockScenario) {
        guard let idx = scenarios.firstIndex(where: { $0.id == scenario.id }) else { return }
        scenarios[idx] = scenario
        persistence.saveScenarios(scenarios)
        pushToMatcher()
    }

    public func removeScenario(id: UUID) {
        scenarios.removeAll { $0.id == id }
        persistence.saveScenarios(scenarios)
        pushToMatcher()
    }

    public func activateScenario(id: UUID) {
        for i in scenarios.indices { scenarios[i].isActive = scenarios[i].id == id }
        persistence.saveScenarios(scenarios)
        pushToMatcher()
    }

    public func deactivateAllScenarios() {
        for i in scenarios.indices { scenarios[i].isActive = false }
        persistence.saveScenarios(scenarios)
        pushToMatcher()
    }

    // MARK: - Hits

    public func clearHits() { hits.removeAll() }

    func recordHit(_ hit: MockHit) {
        hits.insert(hit, at: 0)
        if hits.count > maxHits { hits.removeLast(hits.count - maxHits) }
        if let idx = rules.firstIndex(where: { $0.id == hit.ruleID }) {
            var updated = rules
            updated[idx].hitCount += 1
            updated[idx].lastHitAt = hit.date
            rules = updated
            persistence.saveRules(rules)
            pushToMatcher()
        }
    }

    // MARK: - Thread-safe snapshot

    private func pushToMatcher() {
        let activeScenario = scenarios.first(where: { $0.isActive })
        RuleMatcher.shared.update(
            rules: rules,
            scenarioRuleIDs: activeScenario?.ruleIDs,
            logToInspectKit: InspectKitMock.shared.configuration.logToInspectKit
        )
    }
}
