#if canImport(UIKit)
import Foundation

public extension URLSessionConfiguration {

    /// Returns a `.default` configuration with the inspector's URLProtocol installed.
    static func networkInspectorDefault() -> URLSessionConfiguration {
        URLSessionConfiguration.default.installInspectKit()
    }

    /// Returns a `.ephemeral` configuration with the inspector's URLProtocol installed.
    static func networkInspectorEphemeral() -> URLSessionConfiguration {
        URLSessionConfiguration.ephemeral.installInspectKit()
    }

    /// Installs the inspector's URLProtocol into this configuration **in-place**.
    ///
    /// Call this on any custom configuration before passing it to `URLSession` or
    /// Alamofire's `Session`. Must be called before the session is initialised.
    ///
    /// **Alamofire with a custom interceptor/configuration:**
    /// ```swift
    /// // Build your configuration as usual
    /// let config = URLSessionConfiguration.default
    /// config.timeoutIntervalForRequest = 30
    /// // ... add headers, cache policy, etc. ...
    ///
    /// // Install the inspector LAST, before creating the Session
    /// config.installInspectKit()
    ///
    /// let session = Session(
    ///     configuration: config,
    ///     interceptor: MyRequestInterceptor()
    /// )
    /// ```
    ///
    /// > **Important:** `InspectKit.shared.start()` must be called before
    /// > any requests are made, otherwise `canInit` will refuse to intercept them.
    @discardableResult
    func installInspectKit() -> URLSessionConfiguration {
        var classes = protocolClasses ?? []
        if !classes.contains(where: { $0 == InspectKitURLProtocol.self }) {
            classes.insert(InspectKitURLProtocol.self, at: 0)
        }
        protocolClasses = classes
        return self
    }
}

#endif // canImport(UIKit)
