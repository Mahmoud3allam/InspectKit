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
    public init() {}

    public func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        guard InspectKitURLProtocol.isActive else { return }
        guard InspectKit.shared.configuration.shouldCapture(host: urlRequest.url?.host) else { return }

        let id = UUID()
        let seq = InspectKit.shared.store.nextSequence()
        let headers = urlRequest.allHTTPHeaderFields ?? [:]
        let body = captureRequestBody(from: urlRequest)

        let record = NetworkRequestRecord(
            id: id,
            sequence: seq,
            url: urlRequest.url,
            method: .from(urlRequest.httpMethod),
            requestHeaders: headers,
            requestBody: body,
            environment: InspectKit.shared.configuration.environmentName
        )

        objc_setAssociatedObject(
            request,
            &InspectKitAlamofireMonitor.requestIDKey,
            id,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        Task { @MainActor in
            InspectKit.shared.store.insert(record)
        }
    }

    public func request(_ request: Request,
                       didReceive response: HTTPURLResponse,
                       withData data: Data) {
        guard let id = requestID(for: request) else { return }

        Task { @MainActor in
            InspectKit.shared.finishRecord(
                id: id,
                response: response,
                responseData: data,
                error: nil
            )
        }
    }

    public func request(_ request: Request,
                       didFailWithError error: AFError) {
        guard let id = requestID(for: request) else { return }

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
        objc_getAssociatedObject(request, &Self.requestIDKey) as? UUID
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
