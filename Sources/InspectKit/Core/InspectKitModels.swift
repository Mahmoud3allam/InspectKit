import Foundation

public enum NetworkRequestState: String, Codable, Sendable {
    case inProgress
    case completed
    case failed
    case cancelled
}

public enum HTTPMethod: String, Codable, Sendable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, TRACE, CONNECT, OTHER

    public static func from(_ raw: String?) -> HTTPMethod {
        guard let raw, let m = HTTPMethod(rawValue: raw.uppercased()) else { return .OTHER }
        return m
    }
}

public enum BodyKind: String, Codable, Sendable {
    case none
    case json
    case text
    case form
    case multipart
    case image
    case binary
}

public struct CapturedBody: Codable, Sendable, Hashable {
    public var kind: BodyKind
    public var contentType: String?
    public var byteCount: Int
    public var data: Data?
    public var textPreview: String?
    public var isTruncated: Bool

    public init(kind: BodyKind = .none,
                contentType: String? = nil,
                byteCount: Int = 0,
                data: Data? = nil,
                textPreview: String? = nil,
                isTruncated: Bool = false) {
        self.kind = kind
        self.contentType = contentType
        self.byteCount = byteCount
        self.data = data
        self.textPreview = textPreview
        self.isTruncated = isTruncated
    }
}

public struct CapturedError: Codable, Sendable, Hashable {
    public var localizedDescription: String
    public var domain: String?
    public var code: Int?

    public init(_ error: Error) {
        self.localizedDescription = error.localizedDescription
        let ns = error as NSError
        self.domain = ns.domain
        self.code = ns.code
    }
}

public struct CapturedTransactionMetric: Codable, Sendable, Hashable {
    public var request: String?
    public var networkProtocolName: String?
    public var isReusedConnection: Bool
    public var isProxyConnection: Bool
    public var resourceFetchType: String

    public var fetchStart: Date?
    public var domainLookupStart: Date?
    public var domainLookupEnd: Date?
    public var connectStart: Date?
    public var secureConnectionStart: Date?
    public var secureConnectionEnd: Date?
    public var connectEnd: Date?
    public var requestStart: Date?
    public var requestEnd: Date?
    public var responseStart: Date?
    public var responseEnd: Date?

    public var localAddress: String?
    public var remoteAddress: String?

    public var dnsDurationMS: Double? {
        guard let s = domainLookupStart, let e = domainLookupEnd else { return nil }
        return e.timeIntervalSince(s) * 1000
    }
    public var connectDurationMS: Double? {
        guard let s = connectStart, let e = connectEnd else { return nil }
        return e.timeIntervalSince(s) * 1000
    }
    public var tlsDurationMS: Double? {
        guard let s = secureConnectionStart, let e = secureConnectionEnd else { return nil }
        return e.timeIntervalSince(s) * 1000
    }
    public var requestDurationMS: Double? {
        guard let s = requestStart, let e = requestEnd else { return nil }
        return e.timeIntervalSince(s) * 1000
    }
    public var responseDurationMS: Double? {
        guard let s = responseStart, let e = responseEnd else { return nil }
        return e.timeIntervalSince(s) * 1000
    }
    public var totalDurationMS: Double? {
        guard let s = fetchStart ?? domainLookupStart ?? requestStart,
              let e = responseEnd ?? requestEnd else { return nil }
        return e.timeIntervalSince(s) * 1000
    }
}

public struct CapturedMetrics: Codable, Sendable, Hashable {
    public var taskIntervalStart: Date?
    public var taskIntervalEnd: Date?
    public var redirectCount: Int
    public var transactions: [CapturedTransactionMetric]

    public init(taskIntervalStart: Date? = nil,
                taskIntervalEnd: Date? = nil,
                redirectCount: Int = 0,
                transactions: [CapturedTransactionMetric] = []) {
        self.taskIntervalStart = taskIntervalStart
        self.taskIntervalEnd = taskIntervalEnd
        self.redirectCount = redirectCount
        self.transactions = transactions
    }
}

public struct NetworkRequestRecord: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let sequence: Int

    public var urlString: String
    public var host: String?
    public var path: String
    public var queryItems: [String: String]
    public var method: HTTPMethod
    public var requestHeaders: [String: String]
    public var requestBody: CapturedBody

    public var statusCode: Int?
    public var responseHeaders: [String: String]
    public var responseBody: CapturedBody

    public var error: CapturedError?

    public var startDate: Date
    public var endDate: Date?
    public var durationMS: Double? {
        guard let endDate else { return nil }
        return endDate.timeIntervalSince(startDate) * 1000
    }

    public var metrics: CapturedMetrics?
    public var state: NetworkRequestState
    public var environment: String?

    public init(id: UUID = UUID(),
                sequence: Int,
                url: URL?,
                method: HTTPMethod,
                requestHeaders: [String: String] = [:],
                requestBody: CapturedBody = CapturedBody(),
                startDate: Date = Date(),
                environment: String? = nil) {
        self.id = id
        self.sequence = sequence
        self.urlString = url?.absoluteString ?? ""
        self.host = url?.host
        self.path = url?.path ?? ""
        self.queryItems = Self.extractQueryItems(url)
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseHeaders = [:]
        self.responseBody = CapturedBody()
        self.startDate = startDate
        self.state = .inProgress
        self.environment = environment
    }

    public var isSuccess: Bool {
        guard let code = statusCode else { return false }
        return (200..<300).contains(code)
    }

    public var isFailure: Bool {
        if error != nil { return true }
        if let code = statusCode, code >= 400 { return true }
        return false
    }

    public var displayEndpoint: String {
        if path.isEmpty { return urlString }
        return path
    }

    private static func extractQueryItems(_ url: URL?) -> [String: String] {
        guard let url,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { return [:] }
        var dict: [String: String] = [:]
        for item in items { dict[item.name] = item.value ?? "" }
        return dict
    }
}
