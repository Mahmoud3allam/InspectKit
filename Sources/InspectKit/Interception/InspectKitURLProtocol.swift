import Foundation

/// Custom `URLProtocol` that intercepts requests going through monitored
/// `URLSessionConfiguration`s. It forwards each request through a private
/// `URLSession` so the original behavior is preserved, while capturing the
/// request/response/error and associated metrics into `InspectKit`.
public final class InspectKitURLProtocol: URLProtocol {

    // MARK: - Active flag (thread-safe, set by InspectKit.start/stop)

    private static let _activeLock = NSLock()
    private static var _isActive: Bool = false

    static var isActive: Bool {
        get {
            _activeLock.lock(); defer { _activeLock.unlock() }
            return _isActive
        }
        set {
            _activeLock.lock(); defer { _activeLock.unlock() }
            _isActive = newValue
        }
    }

    // MARK: - Shared forwarding session

    private static let delegateProxy: InspectKitSessionDelegateProxy = {
        let proxy = InspectKitSessionDelegateProxy()
        proxy.metricsHandler = { task, metrics in
            guard let req = task.originalRequest ?? task.currentRequest else { return }
            guard let id = InspectKitRequestMarker.recordID(from: req) else { return }
            Task { @MainActor in
                InspectKit.shared.attachMetrics(id: id, metrics: metrics)
            }
        }
        return proxy
    }()

    private static let forwardingSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []          // prevent re-entry into our own protocol
        config.httpCookieStorage = .shared   // share the app's cookie jar so session cookies are sent
        config.httpShouldSetCookies = true
        config.urlCache = .shared            // honour per-request cachePolicy
        return URLSession(configuration: config, delegate: delegateProxy, delegateQueue: nil)
    }()

    // MARK: - URLProtocol plumbing

    public override class func canInit(with request: URLRequest) -> Bool {
        guard isActive else { return false }
        guard !InspectKitRequestMarker.isHandled(request) else { return false }
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        super.requestIsCacheEquivalent(a, to: b)
    }

    // MARK: - State

    private var dataTask: URLSessionDataTask?
    private var accumulatedData = Data()
    private var accumulationCapped = false
    private var receivedResponse: URLResponse?
    private var recordID: UUID?

    /// Hard cap on how many bytes are buffered internally for the InspectKit UI.
    /// All response bytes are still forwarded to the original client regardless of this cap.
    private static let captureBodyCap = 10 * 1024 * 1024  // 10 MB

    // MARK: - Lifecycle

    public override func startLoading() {
        let original = self.request
        let recordID = beginInspection(for: original)
        self.recordID = recordID

        let forwarded = InspectKitRequestMarker.mark(original, recordID: recordID)
        let task = Self.forwardingSession.dataTask(with: forwarded)
        Self.delegateProxy.register(self, for: task)
        self.dataTask = task
        task.resume()
    }

    public override func stopLoading() {
        dataTask?.cancel()
    }

    // MARK: - Bridge from delegate proxy back to URLProtocol client

    func forwardResponse(_ response: URLResponse) {
        receivedResponse = response
        // .allowed lets the URL loading system honour Cache-Control / ETag headers normally.
        // The previous .notAllowed was silently preventing all HTTP caching for intercepted requests.
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
    }

    func forwardData(_ data: Data) {
        // Buffer up to captureBodyCap for the InspectKit UI; forward ALL bytes to the client.
        if !accumulationCapped {
            let space = Self.captureBodyCap - accumulatedData.count
            if space > 0 { accumulatedData.append(data.prefix(space)) }
            if accumulatedData.count >= Self.captureBodyCap { accumulationCapped = true }
        }
        client?.urlProtocol(self, didLoad: data)
    }

    func forwardCompletion(error: Error?) {
        let response = receivedResponse as? HTTPURLResponse
        let data = accumulatedData
        let recordID = self.recordID

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }

        if let recordID {
            Task { @MainActor in
                InspectKit.shared.finishRecord(id: recordID,
                                                    response: response,
                                                    responseData: data,
                                                    error: error)
            }
        }
    }

    // MARK: - Private

    private func beginInspection(for request: URLRequest) -> UUID? {
        let id = UUID()
        Task { @MainActor in
            guard InspectKit.shared.configuration.shouldCapture(host: request.url?.host) else { return }
            let seq = InspectKit.shared.store.nextSequence()
            let headers = request.allHTTPHeaderFields ?? [:]
            let body = Self.capturedRequestBody(from: request,
                                                config: InspectKit.shared.configuration)
            let record = NetworkRequestRecord(id: id,
                                              sequence: seq,
                                              url: request.url,
                                              method: .from(request.httpMethod),
                                              requestHeaders: headers,
                                              requestBody: body,
                                              environment: InspectKit.shared.configuration.environmentName)
            InspectKit.shared.store.insert(record)
            // Apply any completion/metrics that arrived before this insert ran.
            InspectKit.shared.flushBuffered(for: id)
        }
        return id
    }

    private static func capturedRequestBody(from request: URLRequest,
                                            config: InspectKitConfiguration) -> CapturedBody {
        let ct = (request.allHTTPHeaderFields?.firstValueCaseInsensitive(for: "Content-Type") ?? "")
        let kind = BodyDetection.kind(for: ct)

        // httpBodyStream is a one-shot InputStream shared with the forwarding session's
        // data task.  Reading it here can consume it before URLSession sends the body,
        // resulting in the request going out with an empty body and the server returning
        // an error.  We only capture in-memory body (httpBody); for stream-based requests
        // we fall back to the Content-Length header for the byte count.
        let streamByteCount = Int(request.allHTTPHeaderFields?
                                    .firstValueCaseInsensitive(for: "Content-Length") ?? "") ?? 0

        guard config.captureRequestBodies else {
            let len = request.httpBody?.count ?? streamByteCount
            return CapturedBody(kind: kind, contentType: ct.isEmpty ? nil : ct, byteCount: len,
                                data: nil, textPreview: nil, isTruncated: len > 0)
        }

        let bytes = request.httpBody ?? Data()

        // No in-memory body — stream-based request (multipart, etc.).  Record the
        // byte count but don't touch the stream.
        if bytes.isEmpty {
            return CapturedBody(kind: kind,
                                contentType: ct.isEmpty ? nil : ct,
                                byteCount: streamByteCount,
                                data: nil, textPreview: nil,
                                isTruncated: streamByteCount > 0)
        }

        let cap = config.maxCapturedBodyBytes
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
        return CapturedBody(kind: kind,
                            contentType: ct.isEmpty ? nil : ct,
                            byteCount: bytes.count,
                            data: stored,
                            textPreview: preview,
                            isTruncated: truncated)
    }


}
