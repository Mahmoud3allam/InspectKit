import Foundation
import InspectKitCore

public struct MockRule: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var matcher: RequestMatcher
    public var response: MockResponse
    /// Artificial delay in seconds before the response is delivered.
    public var delay: TimeInterval
    public var hitCount: Int
    public var lastHitAt: Date?

    public init(id: UUID = UUID(),
                name: String,
                isEnabled: Bool = true,
                matcher: RequestMatcher = RequestMatcher(),
                response: MockResponse = MockResponse(kind: .ok(statusCode: 200, headers: [:], body: .none)),
                delay: TimeInterval = 0,
                hitCount: Int = 0,
                lastHitAt: Date? = nil) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.matcher = matcher
        self.response = response
        self.delay = delay
        self.hitCount = hitCount
        self.lastHitAt = lastHitAt
    }
}
