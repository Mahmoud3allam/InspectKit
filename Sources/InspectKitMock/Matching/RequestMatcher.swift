import Foundation
import InspectKitCore

public struct RequestMatcher: Codable, Sendable, Equatable {

    public enum StringMatch: Codable, Sendable, Equatable {
        case equals(String)
        case contains(String)
        case prefix(String)
        case suffix(String)
        case regex(String)

        func matches(_ input: String) -> Bool {
            switch self {
            case .equals(let s):   return input == s
            case .contains(let s): return input.contains(s)
            case .prefix(let s):   return input.hasPrefix(s)
            case .suffix(let s):   return input.hasSuffix(s)
            case .regex(let pattern):
                return (try? NSRegularExpression(pattern: pattern))
                    .map { $0.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil }
                    ?? false
            }
        }
    }

    public var host:         StringMatch?
    public var path:         StringMatch?
    public var method:       HTTPMethod?
    public var query:        [String: StringMatch]
    public var headers:      [String: StringMatch]
    public var bodyContains: String?

    public init(host:         StringMatch? = nil,
                path:         StringMatch? = nil,
                method:       HTTPMethod? = nil,
                query:        [String: StringMatch] = [:],
                headers:      [String: StringMatch] = [:],
                bodyContains: String? = nil) {
        self.host         = host
        self.path         = path
        self.method       = method
        self.query        = query
        self.headers      = headers
        self.bodyContains = bodyContains
    }

    public func matches(_ request: URLRequest) -> Bool {
        if let hostMatch = host {
            guard let h = request.url?.host, hostMatch.matches(h) else { return false }
        }
        if let pathMatch = path {
            let p = request.url?.path ?? ""
            guard pathMatch.matches(p) else { return false }
        }
        if let m = method {
            guard HTTPMethod.from(request.httpMethod) == m else { return false }
        }
        if !query.isEmpty {
            let items = URLComponents(url: request.url ?? URL(string: "/")!,
                                      resolvingAgainstBaseURL: false)?.queryItems ?? []
            let dict = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            for (key, match) in query {
                guard let val = dict[key], match.matches(val) else { return false }
            }
        }
        if !headers.isEmpty {
            let reqHeaders = request.allHTTPHeaderFields ?? [:]
            for (key, match) in headers {
                guard let val = reqHeaders.firstValueCaseInsensitive(for: key),
                      match.matches(val) else { return false }
            }
        }
        if let needle = bodyContains, !needle.isEmpty {
            let body = request.httpBody ?? Data()
            guard let str = String(data: body, encoding: .utf8), str.contains(needle) else {
                return false
            }
        }
        return true
    }
}
