import Foundation
import ObjectiveC

#if canImport(Alamofire)
import Alamofire

/// EventMonitor for Alamofire that captures requests/responses into InspectKit.
/// Use this instead of trying to use URLProtocol interception with Alamofire.
///
/// Example:
/// ```swift
/// let session = Session(eventMonitors: [InspectKitAlamofireMonitor()])
/// ```
public class InspectKitAlamofireMonitor: EventMonitor {
    public init() {
        print("🔧 [InspectKit] AlamofireEventMonitor initialized")
    }

    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        let url = urlRequest.url?.absoluteString ?? "unknown"
        print("📝 [InspectKit] EventMonitor: didCreateURLRequest \(url)")

        guard InspectKitURLProtocol.isActive else {
            print("   ❌ InspectKit not active")
            return
        }
        guard InspectKit.shared.configuration.shouldCapture(host: urlRequest.url?.host) else {
            print("   ❌ shouldCapture=false")
            return
        }

        let id = UUID()
        let seq = InspectKit.shared.store.nextSequence()
        let headers = urlRequest.allHTTPHeaderFields ?? [:]
        let body = captureRequestBody(from: urlRequest)

        print("   ✓ Creating record: \(id.uuidString)")

        let record = NetworkRequestRecord(
            id: id,
            sequence: seq,
            url: urlRequest.url,
            method: .from(urlRequest.httpMethod),
            requestHeaders: headers,
            requestBody: body,
            environment: InspectKit.shared.configuration.environmentName
        )

        // Store the request ID on the request for later lookup
        objc_setAssociatedObject(
            request,
            &InspectKitAlamofireMonitor.requestIDKey,
            id,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        Task { @MainActor in
            print("   ✓ Inserting record into store")
            InspectKit.shared.store.insert(record)
            print("   ✅ Record inserted: \(InspectKit.shared.store.records.count) total")
        }
    }

    public func request(_ request: Request,
                       didReceive response: HTTPURLResponse,
                       withData data: Data) {
        print("📨 [InspectKit] EventMonitor: didReceive \(response.statusCode)")

        guard let id = requestID(for: request) else {
            print("   ❌ No ID found")
            return
        }

        print("   ✓ Found record ID: \(id.uuidString)")

        Task { @MainActor in
            print("   ✓ Finishing record")
            InspectKit.shared.finishRecord(
                id: id,
                response: response,
                responseData: data,
                error: nil
            )
            print("   ✅ Record finished")
        }
    }

    public func request(_ request: Request,
                       didFailWithError error: AFError) {
        print("❌ [InspectKit] EventMonitor: didFailWithError \(error)")

        guard let id = requestID(for: request) else {
            print("   ❌ No ID found")
            return
        }

        Task { @MainActor in
            InspectKit.shared.finishRecord(
                id: id,
                response: nil,
                responseData: nil,
                error: error
            )
        }
    }

    // MARK: - Private

    private static var requestIDKey: UInt8 = 0

    private func requestID(for request: Request) -> UUID? {
        let id = objc_getAssociatedObject(request, &Self.requestIDKey) as? UUID
        print("   [lookup] ID: \(id?.uuidString ?? "nil")")
        return id
    }

    private func captureRequestBody(from request: URLRequest) -> CapturedBody {
        let ct = request.allHTTPHeaderFields?.firstValueCaseInsensitive(for: "Content-Type") ?? ""
        let kind = BodyDetection.kind(for: ct)

        guard InspectKit.shared.configuration.captureRequestBodies else {
            let len = request.httpBody?.count ?? 0
            return CapturedBody(kind: kind, contentType: ct.isEmpty ? nil : ct, byteCount: len,
                                data: nil, textPreview: nil, isTruncated: len > 0)
        }

        var bytes = request.httpBody ?? Data()
        let cap = InspectKit.shared.configuration.maxCapturedBodyBytes
        var stored = bytes
        var truncated = false

        if stored.count > cap {
            stored = stored.prefix(cap)
            truncated = true
        }

        var preview: String? = nil
        if kind == .json || kind == .text || kind == .form {
            preview = String(data: stored, encoding: .utf8) ?? String(data: stored, encoding: .ascii)
        }

        return CapturedBody(
            kind: kind,
            contentType: ct.isEmpty ? nil : ct,
            byteCount: bytes.count,
            data: stored,
            textPreview: preview,
            isTruncated: truncated
        )
    }
}

#endif
