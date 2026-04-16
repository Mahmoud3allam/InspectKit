import Foundation

public struct InspectKitExporter {
    public let redactor: InspectKitRedactor

    public init(redactor: InspectKitRedactor) {
        self.redactor = redactor
    }

    // MARK: - cURL

    public func curl(for record: NetworkRequestRecord, redacted: Bool = true) -> String {
        var lines: [String] = ["curl -v"]
        lines.append("  -X \(record.method.rawValue)")

        let headers = redacted ? redactor.redactHeaders(record.requestHeaders) : record.requestHeaders
        for (k, v) in headers.sorted(by: { $0.key < $1.key }) {
            lines.append("  -H \(shellQuote("\(k): \(v)"))")
        }

        if let body = record.requestBody.data, !body.isEmpty {
            let payload = redacted ? redactor.redactBody(record.requestBody).data ?? body : body
            if let str = String(data: payload, encoding: .utf8) {
                lines.append("  --data-raw \(shellQuote(str))")
            } else {
                lines.append("  --data-binary @-  # (\(payload.count) bytes binary)")
            }
        }

        lines.append("  \(shellQuote(record.urlString))")
        return lines.joined(separator: " \\\n")
    }

    // MARK: - JSON session

    public func jsonSession(records: [NetworkRequestRecord], redacted: Bool = true) throws -> Data {
        let sanitized: [NetworkRequestRecord] = records.map { r in
            var copy = r
            if redacted {
                copy.requestHeaders = redactor.redactHeaders(copy.requestHeaders)
                copy.responseHeaders = redactor.redactHeaders(copy.responseHeaders)
                copy.requestBody = redactor.redactBody(copy.requestBody)
                copy.responseBody = redactor.redactBody(copy.responseBody)
            }
            return copy
        }
        return try JSONEncoder.networkInspector.encode(sanitized)
    }

    public func writeSessionToFile(records: [NetworkRequestRecord],
                                   fileName: String = "network_inspector_export.json",
                                   redacted: Bool = true) throws -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = dir.appendingPathComponent(fileName)
        let data = try jsonSession(records: records, redacted: redacted)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Helpers

    private func shellQuote(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
