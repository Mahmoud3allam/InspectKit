import Foundation

/// A named group of MockRule IDs. When a scenario is active only its member rules are considered.
public struct MockScenario: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var ruleIDs: [UUID]
    public var isActive: Bool

    public init(id: UUID = UUID(),
                name: String,
                ruleIDs: [UUID] = [],
                isActive: Bool = false) {
        self.id = id
        self.name = name
        self.ruleIDs = ruleIDs
        self.isActive = isActive
    }
}
