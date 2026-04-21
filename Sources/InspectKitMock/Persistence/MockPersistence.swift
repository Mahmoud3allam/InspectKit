import Foundation

/// Atomic JSON persistence for MockRules and MockScenarios via UserDefaults.
final class MockPersistence {
    private let rulesKey: String
    private let scenariosKey: String

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.dataEncodingStrategy = .base64
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.dataDecodingStrategy = .base64
        return d
    }()

    init(prefix: String) {
        rulesKey     = "\(prefix).rules"
        scenariosKey = "\(prefix).scenarios"
    }

    func loadRules() -> [MockRule] {
        guard let data = UserDefaults.standard.data(forKey: rulesKey) else { return [] }
        return (try? decoder.decode([MockRule].self, from: data)) ?? []
    }

    func saveRules(_ rules: [MockRule]) {
        guard let data = try? encoder.encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: rulesKey)
    }

    func loadScenarios() -> [MockScenario] {
        guard let data = UserDefaults.standard.data(forKey: scenariosKey) else { return [] }
        return (try? decoder.decode([MockScenario].self, from: data)) ?? []
    }

    func saveScenarios(_ scenarios: [MockScenario]) {
        guard let data = try? encoder.encode(scenarios) else { return }
        UserDefaults.standard.set(data, forKey: scenariosKey)
    }
}
