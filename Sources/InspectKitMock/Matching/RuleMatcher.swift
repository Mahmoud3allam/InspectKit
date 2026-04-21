import Foundation

/// Thread-safe rule matching cache.
///
/// Because URLProtocol's canInit/startLoading run on arbitrary threads and MockStore is
/// @MainActor, we maintain a lock-protected snapshot that MockStore pushes to on every
/// mutation. The URLProtocol reads from here without touching the actor.
final class RuleMatcher: @unchecked Sendable {
    static let shared = RuleMatcher()
    private init() {}

    private let lock = NSLock()
    private var _rules: [MockRule] = []
    private var _scenarioRuleIDs: [UUID]? = nil
    private(set) var logToInspectKit: Bool = true

    func update(rules: [MockRule], scenarioRuleIDs: [UUID]?, logToInspectKit: Bool) {
        lock.lock()
        _rules = rules
        _scenarioRuleIDs = scenarioRuleIDs
        self.logToInspectKit = logToInspectKit
        lock.unlock()
    }

    func firstMatch(for request: URLRequest) -> MockRule? {
        lock.lock()
        defer { lock.unlock() }
        let candidates: [MockRule]
        if let ids = _scenarioRuleIDs {
            candidates = ids.compactMap { id in _rules.first { $0.id == id && $0.isEnabled } }
        } else {
            candidates = _rules.filter { $0.isEnabled }
        }
        return candidates.first { $0.matcher.matches(request) }
    }
}
