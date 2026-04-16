import Foundation

/// Session delegate used by the internal forwarding URLSession inside
/// `InspectKitURLProtocol`. Captures `URLSessionTaskMetrics` per task
/// and bridges completion data back to the URLProtocol client.
final class InspectKitSessionDelegateProxy: NSObject, URLSessionDataDelegate {

    typealias MetricsHandler = (URLSessionTask, URLSessionTaskMetrics) -> Void
    var metricsHandler: MetricsHandler?

    // URLProtocol instance keyed by task identifier so we can forward events.
    private let lock = NSLock()
    private var protocolsByTask: [Int: InspectKitURLProtocol] = [:]

    func register(_ proto: InspectKitURLProtocol, for task: URLSessionTask) {
        lock.lock(); defer { lock.unlock() }
        protocolsByTask[task.taskIdentifier] = proto
    }

    func unregister(_ task: URLSessionTask) {
        lock.lock(); defer { lock.unlock() }
        protocolsByTask.removeValue(forKey: task.taskIdentifier)
    }

    private func proto(for task: URLSessionTask) -> InspectKitURLProtocol? {
        lock.lock(); defer { lock.unlock() }
        return protocolsByTask[task.taskIdentifier]
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        proto(for: dataTask)?.forwardResponse(response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        proto(for: dataTask)?.forwardData(data)
    }

    // MARK: - URLSessionTaskDelegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        proto(for: task)?.forwardCompletion(error: error)
        unregister(task)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Allow redirects; record still reflects the original URL.
        completionHandler(request)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        metricsHandler?(task, metrics)
    }
}
