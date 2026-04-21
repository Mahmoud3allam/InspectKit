import Foundation
import InspectKitCore

/// Public facade for InspectKitMock.
///
/// Typical usage:
/// ```swift
/// import InspectKitMock
/// InspectKitMock.shared.start()
/// let rule = MockRule(name: "Fake login",
///                     matcher: RequestMatcher(path: .contains("/login"), method: .POST),
///                     response: MockResponse(kind: .ok(statusCode: 200,
///                                                      headers: ["Content-Type": "application/json"],
///                                                      body: .json(#"{"token":"fake"}"#))))
/// InspectKitMock.shared.store.add(rule)
/// ```
@MainActor
public final class InspectKitMock {
    public static let shared = InspectKitMock()

    public private(set) var configuration: MockConfiguration = .default
    public let store: MockStore

    public private(set) var isRunning: Bool = false

    private init() {
        let persistence = MockPersistence(prefix: MockConfiguration.default.persistenceKeyPrefix)
        self.store = MockStore(persistence: persistence)
    }

    public func configure(_ configuration: MockConfiguration) {
        self.configuration = configuration
        // Push the updated logToInspectKit flag into the thread-safe matcher cache.
        RuleMatcher.shared.update(
            rules: store.rules,
            scenarioRuleIDs: store.scenarios.first(where: { $0.isActive })?.ruleIDs,
            logToInspectKit: configuration.logToInspectKit
        )
    }

    public func start() {
        guard configuration.isEnabled, !isRunning else { return }
        InspectKitMockURLProtocol.isActive = true
        URLProtocol.registerClass(InspectKitMockURLProtocol.self)
        MockAutoCapture.install()
        isRunning = true
    }

    public func stop() {
        guard isRunning else { return }
        InspectKitMockURLProtocol.isActive = false
        URLProtocol.unregisterClass(InspectKitMockURLProtocol.self)
        CoreAutoCapture.unregister(InspectKitMockURLProtocol.self)
        isRunning = false
    }
}
