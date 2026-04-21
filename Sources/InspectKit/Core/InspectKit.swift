import Foundation
@_exported import InspectKitCore

#if canImport(UIKit)
import UIKit
import SwiftUI
#endif

/// Public facade for the Network Inspector module.
///
/// Typical usage:
/// ```
/// InspectKit.shared.configure(.init(environmentName: "dev"))
/// InspectKit.shared.start()
/// let session = URLSession(configuration: InspectKit.shared.makeMonitoredConfiguration())
/// ```
@MainActor
public final class InspectKit {
    public static let shared = InspectKit()

    public private(set) var configuration: InspectKitConfiguration
    public private(set) var store: InspectKitStore
    public private(set) var redactor: InspectKitRedactor
    public private(set) var exporter: InspectKitExporter
    public private(set) var isRunning: Bool = false

    private init() {
        let config = InspectKitConfiguration.default
        self.configuration = config
        self.store = InspectKitStore(configuration: config)
        self.redactor = InspectKitRedactor(config: config)
        self.exporter = InspectKitExporter(redactor: self.redactor)
    }

    // MARK: - Lifecycle

    public func configure(_ configuration: InspectKitConfiguration) {
        self.configuration = configuration
        self.store = InspectKitStore(configuration: configuration)
        self.redactor = InspectKitRedactor(config: configuration)
        self.exporter = InspectKitExporter(redactor: self.redactor)
    }

    public func start() {
        guard configuration.isEnabled, !isRunning else { return }
        InspectKitURLProtocol.isActive = true
        URLProtocol.registerClass(InspectKitURLProtocol.self)
        InspectKitAutoCapture.install()
        isRunning = true
        // Allow InspectKitMock to log mocked requests into this store
        MockHooks.onHit = { [weak self] record in
            self?.store.insert(record)
        }
    }

    public func stop() {
        guard isRunning else { return }
        InspectKitURLProtocol.isActive = false
        URLProtocol.unregisterClass(InspectKitURLProtocol.self)
        MockHooks.onHit = nil
        isRunning = false
    }

    public func clear() {
        store.clear()
    }

    // MARK: - Integration

    /// The raw `URLProtocol` class used for interception.
    ///
    /// Use this when your network layer lives in a **separate module** that cannot
    /// import InspectKit. Pass it from the app target, which imports both:
    ///
    /// ```swift
    /// // App target (imports both InspectKit and YourNetworkLayer)
    /// YourNetworkLayer.shared.debugProtocolClasses = [InspectKit.urlProtocolClass]
    /// ```
    ///
    /// Then in your network layer (no InspectKit import needed):
    /// ```swift
    /// // YourNetworkLayer module
    /// public var debugProtocolClasses: [AnyClass] = []
    ///
    /// private func makeSessionConfiguration() -> URLSessionConfiguration {
    ///     let config = URLSessionConfiguration.default
    ///     // ... your existing config ...
    ///     var classes = config.protocolClasses ?? []
    ///     classes.insert(contentsOf: debugProtocolClasses, at: 0)
    ///     config.protocolClasses = classes
    ///     return config
    /// }
    /// ```
    public static var urlProtocolClass: AnyClass {
        InspectKitURLProtocol.self
    }

    /// Returns a URLSessionConfiguration with the inspector's URLProtocol installed.
    /// Works with `.default`, `.ephemeral`, or a custom starting configuration.
    ///
    /// **Alamofire usage:**
    /// ```swift
    /// let config = InspectKit.shared.makeMonitoredConfiguration()
    /// let session = Session(configuration: config)
    /// ```
    /// If you already have a custom Alamofire configuration with interceptors, pass it as `base`:
    /// ```swift
    /// let config = InspectKit.shared.makeMonitoredConfiguration(base: myExistingConfig)
    /// let session = Session(configuration: config)
    /// ```
    public func makeMonitoredConfiguration(base: URLSessionConfiguration = .default) -> URLSessionConfiguration {
        let copy = base
        var classes = copy.protocolClasses ?? []
        if !classes.contains(where: { $0 == InspectKitURLProtocol.self }) {
            classes.insert(InspectKitURLProtocol.self, at: 0)
        }
        copy.protocolClasses = classes
        return copy
    }

    // MARK: - UIKit integration

    #if canImport(UIKit)

    /// Installs the floating bubble overlay into a UIWindow (AppDelegate apps).
    ///
    /// Call once from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
    /// after calling `configure` and `start`.
    ///
    /// - Parameters:
    ///   - customIcon: Image shown inside the bubble. `nil` = default "network" SF Symbol.
    ///   - imageContentMode: How the custom icon is scaled. Default `.fit`.
    ///   - bubbleColor: Background colour of the bubble. `nil` = default accent gradient.
    public func installWindowOverlay(in window: UIWindow,
                                     customIcon: UIImage? = nil,
                                     imageContentMode: ContentMode = .fit,
                                     bubbleColor: Color? = nil) {
        InspectKitWindowOverlay.shared.install(in: window,
                                               customIcon: customIcon,
                                               imageContentMode: imageContentMode,
                                               bubbleColor: bubbleColor)
    }

    /// Installs the floating bubble overlay into a UIWindowScene (SceneDelegate apps).
    ///
    /// Call once from `SceneDelegate.scene(_:willConnectTo:options:)`.
    ///
    /// - Parameters:
    ///   - customIcon: Image shown inside the bubble. `nil` = default "network" SF Symbol.
    ///   - imageContentMode: How the custom icon is scaled. Default `.fit`.
    ///   - bubbleColor: Background colour of the bubble. `nil` = default accent gradient.
    public func installWindowOverlay(in scene: UIWindowScene,
                                     customIcon: UIImage? = nil,
                                     imageContentMode: ContentMode = .fit,
                                     bubbleColor: Color? = nil) {
        InspectKitWindowOverlay.shared.install(in: scene,
                                               customIcon: customIcon,
                                               imageContentMode: imageContentMode,
                                               bubbleColor: bubbleColor)
    }

    /// Removes the floating overlay window.
    public func removeWindowOverlay() {
        InspectKitWindowOverlay.shared.remove()
    }

    /// Presents the inspector dashboard from `viewController` as a full-screen modal.
    public func present(from viewController: UIViewController, animated: Bool = true) {
        viewController.presentInspectKit(animated: animated)
    }

    #endif

    // MARK: - Export helpers

    public func curl(for record: NetworkRequestRecord) -> String {
        exporter.curl(for: record, redacted: true)
    }

    public func exportSessionJSON() throws -> Data {
        try exporter.jsonSession(records: store.records)
    }

    public func exportSessionFile() throws -> URL {
        try exporter.writeSessionToFile(records: store.records)
    }

    // MARK: - Capture hooks (used by URLProtocol)

    // Buffers completions that arrive (via delegate) before the insert Task has run.
    // This race can occur when a response is served from cache almost instantaneously.
    private struct BufferedCompletion {
        var response: HTTPURLResponse?
        var responseData: Data?
        var error: Error?
    }
    private var bufferedCompletions: [UUID: BufferedCompletion] = [:]
    private var bufferedMetrics: [UUID: URLSessionTaskMetrics] = [:]

    func finishRecord(id: UUID,
                      response: HTTPURLResponse?,
                      responseData: Data?,
                      error: Error?) {
        guard store.record(for: id) != nil else {
            // Record not yet inserted — buffer and apply once insert runs.
            bufferedCompletions[id] = BufferedCompletion(response: response,
                                                         responseData: responseData,
                                                         error: error)
            return
        }
        applyCompletion(id: id, response: response, responseData: responseData, error: error)
    }

    private func applyCompletion(id: UUID,
                                 response: HTTPURLResponse?,
                                 responseData: Data?,
                                 error: Error?) {
        store.mutate(id: id) { r in
            r.endDate = Date()
            if let response {
                r.statusCode = response.statusCode
                var headers: [String: String] = [:]
                for (k, v) in response.allHeaderFields {
                    if let ks = k as? String, let vs = v as? String { headers[ks] = vs }
                }
                r.responseHeaders = headers
                let contentType = headers.firstValueCaseInsensitive(for: "Content-Type")
                r.responseBody = self.capturedBody(from: responseData,
                                                   stream: nil,
                                                   contentType: contentType,
                                                   allowCapture: self.configuration.captureResponseBodies)
            } else if let responseData {
                r.responseBody = self.capturedBody(from: responseData,
                                                   stream: nil,
                                                   contentType: nil,
                                                   allowCapture: self.configuration.captureResponseBodies)
            }
            if let error {
                r.error = CapturedError(error)
                r.state = (error as NSError).code == NSURLErrorCancelled ? .cancelled : .failed
            } else {
                r.state = .completed
            }
        }
    }

    func attachMetrics(id: UUID, metrics: URLSessionTaskMetrics) {
        guard configuration.captureMetrics else { return }
        guard store.record(for: id) != nil else {
            bufferedMetrics[id] = metrics
            return
        }
        applyMetrics(id: id, metrics: metrics)
    }

    private func applyMetrics(id: UUID, metrics: URLSessionTaskMetrics) {
        let captured = CapturedMetrics(
            taskIntervalStart: metrics.taskInterval.start,
            taskIntervalEnd: metrics.taskInterval.end,
            redirectCount: metrics.redirectCount,
            transactions: metrics.transactionMetrics.map(Self.toCaptured)
        )
        store.mutate(id: id) { r in
            r.metrics = captured
        }
    }

    /// Called after a record is inserted to apply any completion/metrics that
    /// arrived before the insert Task ran (rare race with cached responses).
    func flushBuffered(for id: UUID) {
        if let buffered = bufferedCompletions.removeValue(forKey: id) {
            applyCompletion(id: id,
                            response: buffered.response,
                            responseData: buffered.responseData,
                            error: buffered.error)
        }
        if let metrics = bufferedMetrics.removeValue(forKey: id) {
            applyMetrics(id: id, metrics: metrics)
        }
    }

    private static func toCaptured(_ t: URLSessionTaskTransactionMetrics) -> CapturedTransactionMetric {
        CapturedTransactionMetric(
            request: t.request.url?.absoluteString,
            networkProtocolName: t.networkProtocolName,
            isReusedConnection: t.isReusedConnection,
            isProxyConnection: t.isProxyConnection,
            resourceFetchType: {
                switch t.resourceFetchType {
                case .networkLoad: return "networkLoad"
                case .serverPush: return "serverPush"
                case .localCache: return "localCache"
                case .unknown: return "unknown"
                @unknown default: return "unknown"
                }
            }(),
            fetchStart: t.fetchStartDate,
            domainLookupStart: t.domainLookupStartDate,
            domainLookupEnd: t.domainLookupEndDate,
            connectStart: t.connectStartDate,
            secureConnectionStart: t.secureConnectionStartDate,
            secureConnectionEnd: t.secureConnectionEndDate,
            connectEnd: t.connectEndDate,
            requestStart: t.requestStartDate,
            requestEnd: t.requestEndDate,
            responseStart: t.responseStartDate,
            responseEnd: t.responseEndDate,
            localAddress: nil,
            remoteAddress: nil
        )
    }

    // MARK: - Body capture

    private func capturedBody(from data: Data?,
                              stream: InputStream?,
                              contentType: String?,
                              allowCapture: Bool) -> CapturedBody {
        let ct = (contentType ?? "").lowercased()
        let kind = BodyDetection.kind(for: ct)

        guard allowCapture else {
            let length = data?.count ?? 0
            return CapturedBody(kind: kind, contentType: contentType, byteCount: length, data: nil, textPreview: nil, isTruncated: length > 0)
        }

        var bytes = data ?? Data()
        if bytes.isEmpty, let stream {
            bytes = Self.readStream(stream)
        }
        let originalCount = bytes.count

        if originalCount == 0 {
            return CapturedBody(kind: .none, contentType: contentType, byteCount: 0)
        }

        let cap = configuration.maxCapturedBodyBytes
        var truncated = false
        var stored = bytes
        if stored.count > cap {
            stored = stored.prefix(cap)
            truncated = true
        }

        var textPreview: String? = nil
        if kind == .json || kind == .text || kind == .form {
            if let s = String(data: stored, encoding: .utf8) ?? String(data: stored, encoding: .ascii) {
                textPreview = s
            }
        }

        return CapturedBody(kind: kind,
                            contentType: contentType,
                            byteCount: originalCount,
                            data: stored,
                            textPreview: textPreview,
                            isTruncated: truncated)
    }

    private static func readStream(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        defer { stream.close() }
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
            if data.count > 10_000_000 { break } // hard safety cap
        }
        return data
    }
}

