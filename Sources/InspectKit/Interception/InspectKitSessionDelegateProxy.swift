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
        // Only follow redirects that stay on http/https.
        // If the Location header points to a custom scheme (e.g. myapp://, file://)
        // our forwarding session can't handle it and raises NSURLErrorUnsupportedURL.
        // Passing nil cancels the redirect and returns the 302 response to the caller,
        // which matches what URLSession does for non-HTTP redirect targets natively.
        let scheme = request.url?.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        metricsHandler?(task, metrics)
    }

    // MARK: - Authentication challenges

    /// Session-level challenge (e.g. SSL client certificates for the whole session).
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    /// Task-level challenge (e.g. server-trust evaluation, HTTP Basic/Digest auth).
    /// Using .performDefaultHandling means the system trust chain is used, which is
    /// equivalent to what URLSession does when no delegate is present — but being
    /// explicit here prevents URLSession from silently cancelling challenges for
    /// dev/staging servers that have custom CAs.
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - Cache

    /// Pass the proposed cached response through unchanged so the URL loading
    /// system's normal cache decision is honoured.
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCache proposedResponse: CachedURLResponse,
                    completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(proposedResponse)
    }
}
