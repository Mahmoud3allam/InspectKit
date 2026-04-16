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
        config.protocolClasses = [] // critical: avoid re-entry into our protocol
        return URLSession(configuration: config, delegate: delegateProxy, delegateQueue: nil)
    }()

    // MARK: - URLProtocol plumbing

    public override class func canInit(with request: URLRequest) -> Bool {
        let url = request.url?.absoluteString ?? "unknown"
        print("🔵 [InspectKit] canInit called for: \(url)")

        guard isActive else {
            print("   ❌ Not active (isActive=\(isActive))")
            return false
        }
        print("   ✓ isActive=true")

        if InspectKitRequestMarker.isHandled(request) {
            print("   ❌ Already handled")
            return false
        }
        print("   ✓ Not already handled")

        guard let scheme = request.url?.scheme?.lowercased() else {
            print("   ❌ No scheme")
            return false
        }
        print("   ✓ Scheme: \(scheme)")

        guard scheme == "http" || scheme == "https" else {
            print("   ❌ Not http/https")
            return false
        }
        print("   ✅ WILL INTERCEPT")
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
    private var receivedResponse: URLResponse?
    private var recordID: UUID?

    // MARK: - Lifecycle

    public override func startLoading() {
        let url = self.request.url?.absoluteString ?? "unknown"
        print("🟢 [InspectKit] startLoading called for: \(url)")

        let original = self.request
        let recordID = beginInspection(for: original)
        self.recordID = recordID
        print("   ✓ Created record ID: \(recordID?.uuidString ?? "nil")")

        let forwarded = InspectKitRequestMarker.mark(original, recordID: recordID)
        let task = Self.forwardingSession.dataTask(with: forwarded)
        Self.delegateProxy.register(self, for: task)
        self.dataTask = task
        task.resume()
        print("   ✅ Task resumed")
    }

    public override func stopLoading() {
        dataTask?.cancel()
    }

    // MARK: - Bridge from delegate proxy back to URLProtocol client

    func forwardResponse(_ response: URLResponse) {
        receivedResponse = response
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    func forwardData(_ data: Data) {
        accumulatedData.append(data)
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

        guard config.captureRequestBodies else {
            let len = request.httpBody?.count ?? 0
            return CapturedBody(kind: kind, contentType: ct.isEmpty ? nil : ct, byteCount: len,
                                data: nil, textPreview: nil, isTruncated: len > 0)
        }

        var bytes = request.httpBody ?? Data()
        if bytes.isEmpty, let stream = request.httpBodyStream {
            bytes = readStream(stream)
        }
        if bytes.isEmpty {
            return CapturedBody(kind: .none, contentType: ct.isEmpty ? nil : ct, byteCount: 0)
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

    private static func readStream(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        defer { stream.close() }
        let size = 4096
        var buf = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buf, maxLength: size)
            if read <= 0 { break }
            data.append(buf, count: read)
            if data.count > 10_000_000 { break }
        }
        return data
    }
}
