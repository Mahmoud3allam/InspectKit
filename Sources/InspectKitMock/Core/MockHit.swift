import Foundation
import InspectKitCore

/// A single record of a matched (mocked) network request. Held in a rolling log.
public struct MockHit: Identifiable, Codable, Sendable {
    public let id: UUID
    public let ruleID: UUID
    public let ruleName: String
    public let url: URL?
    public let method: HTTPMethod
    public let statusCode: Int?
    public let date: Date

    public init(id: UUID = UUID(),
                ruleID: UUID,
                ruleName: String,
                url: URL?,
                method: HTTPMethod,
                statusCode: Int?,
                date: Date = Date()) {
        self.id = id
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.url = url
        self.method = method
        self.statusCode = statusCode
        self.date = date
    }
}
