import Foundation

public struct MockConfiguration: Sendable {
    public var isEnabled: Bool
    /// When true (default), requests that match no rule go to the real network unchanged.
    public var passThroughOnMiss: Bool
    /// When true, mocked requests also appear in the InspectKit dashboard (if running).
    public var logToInspectKit: Bool
    /// UserDefaults key prefix used for persistence.
    public var persistenceKeyPrefix: String

    public static let `default` = MockConfiguration()

    public init(isEnabled: Bool = true,
                passThroughOnMiss: Bool = true,
                logToInspectKit: Bool = true,
                persistenceKeyPrefix: String = "InspectKitMock") {
        self.isEnabled = isEnabled
        self.passThroughOnMiss = passThroughOnMiss
        self.logToInspectKit = logToInspectKit
        self.persistenceKeyPrefix = persistenceKeyPrefix
    }
}
