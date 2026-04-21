import Foundation
import InspectKitCore

/// URLProtocol that short-circuits matching requests with configured fake responses.
/// Uses the thread-safe RuleMatcher cache so canInit/startLoading never touch the @MainActor store.
public final class InspectKitMockURLProtocol: URLProtocol {

    // MARK: - Active flag

    private static let _lock = NSLock()
    private static var _isActive = false

    static var isActive: Bool {
        get { _lock.lock(); defer { _lock.unlock() }; return _isActive }
        set { _lock.lock(); defer { _lock.unlock() }; _isActive = newValue }
    }

    // MARK: - URLProtocol

    public override class func canInit(with request: URLRequest) -> Bool {
        guard isActive else { return false }
        guard !InspectKitRequestMarker.isHandled(request) else { return false }
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        return RuleMatcher.shared.firstMatch(for: request) != nil
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    // MARK: - Delivery

    private var workItem: DispatchWorkItem?

    public override func startLoading() {
        let req = self.request
        guard let rule = RuleMatcher.shared.firstMatch(for: req) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let item = DispatchWorkItem { [weak self] in self?.deliver(rule: rule, request: req) }
        workItem = item
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + rule.delay, execute: item)
    }

    public override func stopLoading() {
        workItem?.cancel()
        workItem = nil
    }

    // MARK: - Private

    private func deliver(rule: MockRule, request: URLRequest) {
        switch rule.response.kind {
        case let .ok(statusCode, headers, body):
            let data = body.resolve()
            guard let url = request.url,
                  let httpResp = HTTPURLResponse(url: url, statusCode: statusCode,
                                                 httpVersion: "HTTP/1.1",
                                                 headerFields: headers) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: httpResp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            logHit(rule: rule, request: request, statusCode: statusCode)
            if RuleMatcher.shared.logToInspectKit {
                notifyInspectKit(rule: rule, request: request, statusCode: statusCode,
                                 data: data, headers: headers)
            }

        case let .failure(domain, code, userInfo):
            let info = userInfo.isEmpty ? nil : userInfo as [String: Any]
            let err = NSError(domain: domain, code: code, userInfo: info)
            client?.urlProtocol(self, didFailWithError: err)
            logHit(rule: rule, request: request, statusCode: nil)
            if RuleMatcher.shared.logToInspectKit {
                notifyInspectKit(rule: rule, request: request, statusCode: nil,
                                 data: Data(), headers: [:])
            }
        }
    }

    private func logHit(rule: MockRule, request: URLRequest, statusCode: Int?) {
        let hit = MockHit(ruleID: rule.id,
                          ruleName: rule.name,
                          url: request.url,
                          method: .from(request.httpMethod),
                          statusCode: statusCode)
        DispatchQueue.main.async {
            InspectKitMock.shared.store.recordHit(hit)
        }
    }

    private func notifyInspectKit(rule: MockRule, request: URLRequest,
                                  statusCode: Int?, data: Data,
                                  headers: [String: String]) {
        guard MockHooks.onHit != nil else { return }
        let url = request.url
        let method = HTTPMethod.from(request.httpMethod)
        let ct = headers.firstValueCaseInsensitive(for: "Content-Type") ?? ""
        let bodyKind = BodyDetection.kind(for: ct)
        let reqHeaders = request.allHTTPHeaderFields ?? [:]
        let reqBodyCount = request.httpBody?.count ?? 0
        let ruleName = rule.name

        DispatchQueue.main.async {
            var record = NetworkRequestRecord(
                sequence: 0,
                url: url,
                method: method,
                requestHeaders: reqHeaders,
                requestBody: CapturedBody(kind: .none, byteCount: reqBodyCount)
            )
            record.statusCode = statusCode
            record.responseBody = CapturedBody(kind: bodyKind,
                                               contentType: ct.isEmpty ? nil : ct,
                                               byteCount: data.count,
                                               data: data,
                                               textPreview: String(data: data, encoding: .utf8))
            record.state = statusCode != nil ? .completed : .failed
            record.endDate = Date()
            record.isMocked = true
            record.mockRuleName = ruleName
            MockHooks.onHit?(record)
        }
    }
}
