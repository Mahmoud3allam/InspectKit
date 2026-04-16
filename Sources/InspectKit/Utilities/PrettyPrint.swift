import Foundation

public enum PrettyPrint {

    /// Pretty-prints JSON data. Returns nil if input isn't valid JSON.
    public static func json(_ data: Data) -> String? {
        guard !data.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        guard let out = try? JSONSerialization.data(withJSONObject: obj,
                                                    options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]) else {
            return nil
        }
        return String(data: out, encoding: .utf8)
    }

    /// Decodes bytes as text if possible.
    public static func text(_ data: Data) -> String? {
        if let s = String(data: data, encoding: .utf8), !s.isEmpty { return s }
        if let s = String(data: data, encoding: .isoLatin1), !s.isEmpty { return s }
        if let s = String(data: data, encoding: .ascii), !s.isEmpty { return s }
        return nil
    }

    /// Returns a best-effort readable representation of a body.
    public static func render(body: CapturedBody) -> (text: String, isJSON: Bool) {
        guard let data = body.data, !data.isEmpty else {
            return (body.textPreview ?? "", body.kind == .json)
        }
        if body.kind == .json, let pretty = json(data) {
            return (pretty, true)
        }
        if let t = text(data) {
            return (t, false)
        }
        return ("<\(body.byteCount) bytes binary>", false)
    }
}
