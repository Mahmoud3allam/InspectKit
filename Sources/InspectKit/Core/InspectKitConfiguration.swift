import Foundation

public struct InspectKitConfiguration: Sendable {
    public var isEnabled: Bool
    public var environmentName: String?

    public var allowedHosts: Set<String>
    public var ignoredHosts: Set<String>

    public var maxStoredRequests: Int
    public var maxCapturedBodyBytes: Int

    public var captureRequestBodies: Bool
    public var captureResponseBodies: Bool
    public var captureMetrics: Bool

    public var persistToDisk: Bool
    public var persistenceFileName: String

    public var showsFloatingOverlay: Bool
    public var allowsExport: Bool

    public var redactedHeaderKeys: Set<String>
    public var redactedBodyKeys: Set<String>
    public var redactionPlaceholder: String

    public static let `default` = InspectKitConfiguration()

    public init(isEnabled: Bool = true,
                environmentName: String? = nil,
                allowedHosts: Set<String> = [],
                ignoredHosts: Set<String> = [],
                maxStoredRequests: Int = 500,
                maxCapturedBodyBytes: Int = 1_000_000,
                captureRequestBodies: Bool = true,
                captureResponseBodies: Bool = true,
                captureMetrics: Bool = true,
                persistToDisk: Bool = false,
                persistenceFileName: String = "network_inspector_session.json",
                showsFloatingOverlay: Bool = true,
                allowsExport: Bool = true,
                redactedHeaderKeys: Set<String> = InspectKitConfiguration.defaultRedactedHeaderKeys,
                redactedBodyKeys: Set<String> = InspectKitConfiguration.defaultRedactedBodyKeys,
                redactionPlaceholder: String = "██ REDACTED ██") {
        self.isEnabled = isEnabled
        self.environmentName = environmentName
        self.allowedHosts = allowedHosts
        self.ignoredHosts = ignoredHosts
        self.maxStoredRequests = maxStoredRequests
        self.maxCapturedBodyBytes = maxCapturedBodyBytes
        self.captureRequestBodies = captureRequestBodies
        self.captureResponseBodies = captureResponseBodies
        self.captureMetrics = captureMetrics
        self.persistToDisk = persistToDisk
        self.persistenceFileName = persistenceFileName
        self.showsFloatingOverlay = showsFloatingOverlay
        self.allowsExport = allowsExport
        self.redactedHeaderKeys = redactedHeaderKeys
        self.redactedBodyKeys = redactedBodyKeys
        self.redactionPlaceholder = redactionPlaceholder
    }

    public static let defaultRedactedHeaderKeys: Set<String> = [
        "authorization", "cookie", "set-cookie", "x-api-key", "api-key",
        "proxy-authorization", "x-auth-token"
    ]

    public static let defaultRedactedBodyKeys: Set<String> = [
        "token", "access_token", "refresh_token", "password",
        "secret", "client_secret", "api_key", "apikey"
    ]

    public func shouldCapture(host: String?) -> Bool {
        guard isEnabled else { return false }
        guard let host = host?.lowercased() else { return true }
        if ignoredHosts.contains(where: { host.contains($0.lowercased()) }) { return false }
        if !allowedHosts.isEmpty {
            return allowedHosts.contains(where: { host.contains($0.lowercased()) })
        }
        return true
    }
}
