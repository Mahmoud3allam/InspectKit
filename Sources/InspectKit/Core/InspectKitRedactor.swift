import Foundation

public struct InspectKitRedactor: Sendable {
    public let redactedHeaderKeys: Set<String>
    public let redactedBodyKeys: Set<String>
    public let placeholder: String

    public init(config: InspectKitConfiguration) {
        self.redactedHeaderKeys = Set(config.redactedHeaderKeys.map { $0.lowercased() })
        self.redactedBodyKeys = Set(config.redactedBodyKeys.map { $0.lowercased() })
        self.placeholder = config.redactionPlaceholder
    }

    public init(redactedHeaderKeys: Set<String>, redactedBodyKeys: Set<String>, placeholder: String) {
        self.redactedHeaderKeys = Set(redactedHeaderKeys.map { $0.lowercased() })
        self.redactedBodyKeys = Set(redactedBodyKeys.map { $0.lowercased() })
        self.placeholder = placeholder
    }

    /// A no-op redactor that leaves all values untouched.
    public static let identity = InspectKitRedactor(redactedHeaderKeys: [], redactedBodyKeys: [], placeholder: "")

    public func redactHeaders(_ headers: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in headers {
            if redactedHeaderKeys.contains(k.lowercased()) {
                out[k] = placeholder
            } else {
                out[k] = v
            }
        }
        return out
    }

    public func redactBody(_ body: CapturedBody) -> CapturedBody {
        var copy = body
        guard body.kind == .json, let data = body.data else {
            return copy
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return copy
        }
        let redacted = redactJSON(obj)
        if let newData = try? JSONSerialization.data(withJSONObject: redacted, options: [.prettyPrinted, .fragmentsAllowed]) {
            copy.data = newData
            copy.textPreview = String(data: newData, encoding: .utf8)
        }
        return copy
    }

    public func redactJSON(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for (k, v) in dict {
                if redactedBodyKeys.contains(k.lowercased()) {
                    out[k] = placeholder
                } else {
                    out[k] = redactJSON(v)
                }
            }
            return out
        }
        if let arr = value as? [Any] {
            return arr.map { redactJSON($0) }
        }
        return value
    }

    public func redactedQueryString(from url: URL?) -> String? {
        guard let url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { return nil }
        comps.queryItems = items.map { item in
            if redactedBodyKeys.contains(item.name.lowercased()) {
                return URLQueryItem(name: item.name, value: placeholder)
            }
            return item
        }
        return comps.query
    }
}
