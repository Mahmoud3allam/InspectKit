import Foundation

// MARK: - Phase

public enum SpeedTestPhase: Equatable {
    case idle
    case ping
    case download
    case upload
    case done
    case failed(String)

    var label: String {
        switch self {
        case .idle:            return "Tap Start to begin"
        case .ping:            return "Measuring latency…"
        case .download:        return "Testing download speed…"
        case .upload:          return "Testing upload speed…"
        case .done:            return "Test complete"
        case .failed(let msg): return msg
        }
    }

    var isRunning: Bool {
        switch self { case .ping, .download, .upload: return true; default: return false }
    }
}

// MARK: - Engine

/// Measures ping, download, and upload speed against Cloudflare's public test endpoints.
/// All requests bypass InspectKit's interception so they don't pollute the request list
/// and so the measured throughput reflects real network speed.
@MainActor
public final class InspectKitSpeedTester: ObservableObject {

    @Published public var phase: SpeedTestPhase = .idle
    @Published public var pingMS: Double?        = nil
    @Published public var downloadMbps: Double?  = nil
    @Published public var uploadMbps: Double?    = nil
    @Published public var downloadProgress: Double = 0
    @Published public var uploadProgress: Double   = 0

    private var activeTask: Task<Void, Never>?

    public init() {}

    // MARK: - Public API

    public func start() {
        cancel()
        activeTask = Task { [weak self] in await self?.run() }
    }

    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        phase = .idle
        downloadProgress = 0
        uploadProgress   = 0
    }

    // MARK: - Test runner

    private func run() async {
        pingMS = nil; downloadMbps = nil; uploadMbps = nil
        downloadProgress = 0; uploadProgress = 0

        do {
            // ── Ping ──────────────────────────────────────────────────
            phase = .ping
            var total = 0.0
            for _ in 0 ..< 3 {
                try Task.checkCancellation()
                let ms = try await Self.measurePing()
                total += ms
            }
            pingMS = total / 3

            // ── Download ──────────────────────────────────────────────
            try Task.checkCancellation()
            phase = .download
            downloadMbps = try await measureDownload()

            // ── Upload ────────────────────────────────────────────────
            try Task.checkCancellation()
            phase = .upload
            uploadMbps = try await measureUpload()

            phase = .done

        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Ping

    private static func measurePing() async throws -> Double {
        var req = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=1")!)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 10
        req = InspectKitRequestMarker.mark(req)

        let start = Date()
        _ = try await performRequest(req)
        return Date().timeIntervalSince(start) * 1000
    }

    // MARK: - Download

    private func measureDownload() async throws -> Double {
        var req = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!)
        req.timeoutInterval = 60
        req = InspectKitRequestMarker.mark(req)

        let expectedBytes = 10_000_000

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let delegate = SpeedTestDelegate()
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = []
            config.urlCache = nil
            config.httpCookieStorage = nil
            let session = URLSession(configuration: config,
                                     delegate: delegate,
                                     delegateQueue: .main)

            var received = 0
            let start = Date()
            var resumed = false

            delegate.onData = { data in
                received += data.count
                let progress = min(Double(received) / Double(expectedBytes), 1.0)
                Task { @MainActor [weak self] in self?.downloadProgress = progress }
            }

            delegate.onComplete = { error in
                guard !resumed else { return }
                resumed = true
                session.invalidateAndCancel()
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let elapsed = max(Date().timeIntervalSince(start), 0.001)
                    let mbps = Double(received * 8) / elapsed / 1_000_000
                    continuation.resume(returning: mbps)
                }
            }

            let task = session.dataTask(with: req)
            task.resume()
        }
    }

    // MARK: - Upload

    private func measureUpload() async throws -> Double {
        let payload = Data(repeating: 0x42, count: 2_000_000) // 2 MB

        var req = URLRequest(url: URL(string: "https://speed.cloudflare.com/__up")!)
        req.httpMethod = "POST"
        req.httpBody   = payload
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req = InspectKitRequestMarker.mark(req)

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let delegate = SpeedTestDelegate()
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = []
            config.urlCache = nil
            config.httpCookieStorage = nil
            let session = URLSession(configuration: config,
                                     delegate: delegate,
                                     delegateQueue: .main)

            let start = Date()
            var resumed = false

            delegate.onSent = { bytesSent, total in
                let progress = total > 0 ? min(Double(bytesSent) / Double(total), 1.0) : 0
                Task { @MainActor [weak self] in self?.uploadProgress = progress }
            }

            delegate.onComplete = { error in
                guard !resumed else { return }
                resumed = true
                session.invalidateAndCancel()
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let elapsed = max(Date().timeIntervalSince(start), 0.001)
                    let mbps = Double(payload.count * 8) / elapsed / 1_000_000
                    continuation.resume(returning: mbps)
                }
            }

            let task = session.dataTask(with: req)
            task.resume()
        }
    }

    // MARK: - Generic request helper (ping)

    private static func performRequest(_ request: URLRequest) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = []
            config.urlCache = nil
            config.httpCookieStorage = nil
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: request) { data, _, error in
                session.invalidateAndCancel()
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: data ?? Data()) }
            }
            task.resume()
        }
    }
}

// MARK: - SpeedTestDelegate

/// Non-actor URLSession delegate that bridges callbacks into the tester via closures.
private final class SpeedTestDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {

    var onData:     ((Data) -> Void)?
    var onSent:     ((_ bytesSent: Int64, _ totalExpected: Int64) -> Void)?
    var onComplete: ((Error?) -> Void)?

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        onData?(data)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        onSent?(totalBytesSent, totalBytesExpectedToSend)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        onComplete?(error)
    }
}
