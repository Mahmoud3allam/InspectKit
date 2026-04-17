import Foundation
import Network

#if canImport(UIKit)
import UIKit
#endif

// MARK: - History record

public struct SpeedTestRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let downloadMbps: Double
    public let uploadMbps: Double
    public let pingMS: Double
    public let jitterMS: Double
    public let lossPercent: Double
    public let deviceName: String
    public let connectionType: String
}

// MARK: - Phase

public enum SpeedTestPhase: Equatable {
    case idle
    case ping
    case download
    case upload
    case done
    case failed(String)

    public var isRunning: Bool {
        switch self { case .ping, .download, .upload: return true; default: return false }
    }

    public var label: String {
        switch self {
        case .idle:            return "Tap to begin"
        case .ping:            return "Testing latency…"
        case .download:        return "Testing download…"
        case .upload:          return "Testing upload…"
        case .done:            return "Test complete"
        case .failed(let msg): return msg
        }
    }
}

// MARK: - Engine

@MainActor
public final class InspectKitSpeedTester: ObservableObject {

    // Live gauge
    @Published public var phase: SpeedTestPhase = .idle
    @Published public var currentSpeed: Double   = 0

    // Final results
    @Published public var pingMS: Double?        = nil
    @Published public var jitterMS: Double?      = nil
    @Published public var lossPercent: Double?   = nil
    @Published public var downloadMbps: Double?  = nil
    @Published public var uploadMbps: Double?    = nil

    // Chart
    @Published public var realtimeSamples: [Double] = []

    // History
    @Published public var history: [SpeedTestRecord] = []

    private static let historyKey = "InspectKit.speedHistory"
    private static let maxHistory = 10

    private var activeTask: Task<Void, Never>?

    public init() {
        history = Self.loadHistory()
    }

    // MARK: - Public API

    public func start() {
        cancel()
        activeTask = Task { [weak self] in await self?.run() }
    }

    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        phase = .idle
        currentSpeed = 0
        realtimeSamples = []
    }

    public func clearHistory() {
        history = []
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }

    // MARK: - Test runner

    private func run() async {
        pingMS = nil; jitterMS = nil; lossPercent = nil
        downloadMbps = nil; uploadMbps = nil
        currentSpeed = 0; realtimeSamples = []

        let connectionType = await Self.detectConnectionType()

        do {
            // ── Ping / Jitter / Loss ─────────────────────────────────
            phase = .ping
            let (avg, jitter, loss) = try await Self.runPingBatch()
            try Task.checkCancellation()
            pingMS       = avg
            jitterMS     = jitter
            lossPercent  = loss

            // ── Download ─────────────────────────────────────────────
            phase = .download
            let dl = try await measureDownload()
            try Task.checkCancellation()
            downloadMbps = dl
            currentSpeed = dl

            // ── Upload ───────────────────────────────────────────────
            phase = .upload
            let ul = try await measureUpload()
            try Task.checkCancellation()
            uploadMbps = ul

            phase = .done

            // Save to history
            let record = SpeedTestRecord(
                id: UUID(),
                date: Date(),
                downloadMbps: dl,
                uploadMbps: ul,
                pingMS: avg,
                jitterMS: jitter,
                lossPercent: loss,
                deviceName: Self.deviceName(),
                connectionType: connectionType
            )
            history.insert(record, at: 0)
            if history.count > Self.maxHistory { history = Array(history.prefix(Self.maxHistory)) }
            Self.saveHistory(history)

        } catch is CancellationError {
            phase = .idle
            currentSpeed = 0
        } catch {
            phase = .failed(error.localizedDescription)
            currentSpeed = 0
        }
    }

    // MARK: - Ping batch (5 requests → avg, jitter, loss)

    private static func runPingBatch() async throws -> (avg: Double, jitter: Double, loss: Double) {
        let total = 5
        var times: [Double] = []
        var failures = 0

        for _ in 0 ..< total {
            do {
                times.append(try await measurePing())
            } catch {
                failures += 1
            }
        }

        guard !times.isEmpty else { throw URLError(.notConnectedToInternet) }

        let avg      = times.reduce(0, +) / Double(times.count)
        let variance = times.map { pow($0 - avg, 2) }.reduce(0, +) / Double(times.count)
        let jitter   = sqrt(variance)
        let loss     = Double(failures) / Double(total) * 100

        return (avg, jitter, loss)
    }

    private static func measurePing() async throws -> Double {
        var req = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=1")!)
        req.httpMethod       = "HEAD"
        req.timeoutInterval  = 8
        req = InspectKitRequestMarker.mark(req)

        let start = Date()
        _ = try await Self.performRequest(req)
        return Date().timeIntervalSince(start) * 1000
    }

    // MARK: - Download (10 MB with real-time samples)

    private func measureDownload() async throws -> Double {
        var req = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!)
        req.timeoutInterval = 60
        req = InspectKitRequestMarker.mark(req)

        let expected = 10_000_000

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let delegate = SpeedTestDelegate()
            let session  = Self.makeSession(delegate: delegate)

            var received     = 0
            var lastBytes    = 0
            var lastSample   = Date()
            let start        = Date()
            var resumed      = false

            delegate.onData = { data in
                received += data.count

                // Emit sample every 0.4 s
                let now      = Date()
                let elapsed  = now.timeIntervalSince(lastSample)
                if elapsed >= 0.4 {
                    let chunk   = received - lastBytes
                    let mbps    = Double(chunk * 8) / elapsed / 1_000_000
                    lastBytes   = received
                    lastSample  = now
                    Task { @MainActor [weak self] in
                        self?.currentSpeed = mbps
                        self?.realtimeSamples.append(mbps)
                    }
                }

                let progress = min(Double(received) / Double(expected), 1.0)
                _ = progress // progress is implicit via currentSpeed; no separate bar needed
            }

            delegate.onComplete = { error in
                guard !resumed else { return }
                resumed = true
                session.invalidateAndCancel()
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let elapsed = max(Date().timeIntervalSince(start), 0.001)
                    continuation.resume(returning: Double(received * 8) / elapsed / 1_000_000)
                }
            }

            session.dataTask(with: req).resume()
        }
    }

    // MARK: - Upload (2 MB)

    private func measureUpload() async throws -> Double {
        let payload = Data(repeating: 0x42, count: 2_000_000)

        var req = URLRequest(url: URL(string: "https://speed.cloudflare.com/__up")!)
        req.httpMethod  = "POST"
        req.httpBody    = payload
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req = InspectKitRequestMarker.mark(req)

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let delegate = SpeedTestDelegate()
            let session  = Self.makeSession(delegate: delegate)

            let start   = Date()
            var resumed = false

            delegate.onSent = { sent, total in
                let mbps = total > 0
                    ? Double(sent * 8) / max(Date().timeIntervalSince(start), 0.001) / 1_000_000
                    : 0
                Task { @MainActor [weak self] in self?.currentSpeed = mbps }
            }

            delegate.onComplete = { error in
                guard !resumed else { return }
                resumed = true
                session.invalidateAndCancel()
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let elapsed = max(Date().timeIntervalSince(start), 0.001)
                    continuation.resume(returning: Double(payload.count * 8) / elapsed / 1_000_000)
                }
            }

            session.dataTask(with: req).resume()
        }
    }

    // MARK: - Helpers

    private static func performRequest(_ request: URLRequest) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let session = makeSession(delegate: nil)
            session.dataTask(with: request) { data, _, error in
                session.invalidateAndCancel()
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: data ?? Data()) }
            }.resume()
        }
    }

    private static func makeSession(delegate: (URLSessionDataDelegate & URLSessionTaskDelegate)?) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses   = []
        config.urlCache          = nil
        config.httpCookieStorage = nil
        return URLSession(configuration: config, delegate: delegate, delegateQueue: .main)
    }

    private static func detectConnectionType() async -> String {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            var done = false
            monitor.pathUpdateHandler = { path in
                guard !done else { return }
                done = true
                monitor.cancel()
                if path.usesInterfaceType(.wifi)     { continuation.resume(returning: "WiFi") }
                else if path.usesInterfaceType(.cellular) { continuation.resume(returning: "Cellular") }
                else { continuation.resume(returning: "Unknown") }
            }
            monitor.start(queue: DispatchQueue.global())
        }
    }

    private static func deviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Unknown Device"
        #endif
    }

    // MARK: - History persistence

    private static func loadHistory() -> [SpeedTestRecord] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let records = try? JSONDecoder().decode([SpeedTestRecord].self, from: data)
        else { return [] }
        return records
    }

    private static func saveHistory(_ records: [SpeedTestRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

// MARK: - URLSession delegate bridge

private final class SpeedTestDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    var onData:     ((Data) -> Void)?
    var onSent:     ((_ sent: Int64, _ total: Int64) -> Void)?
    var onComplete: ((Error?) -> Void)?

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onData?(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData: Int64, totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        onSent?(totalBytesSent, totalBytesExpectedToSend)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(error)
    }
}
