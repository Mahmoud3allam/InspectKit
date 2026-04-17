import Foundation
import ObjectiveC

/// Swizzles `URLSessionConfiguration.protocolClasses` at the concrete backing-class level
/// (`__NSCFURLSessionConfiguration`) so that `InspectKitURLProtocol` is appended to every
/// session's protocol list — even sessions created before `InspectKit.start()` is called,
/// and even when the caller has set an explicit `protocolClasses` array.
///
/// This is the same technique used by Wormholy and Netfox.
enum InspectKitAutoCapture {
    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        swizzleProtocolClassesGetter()
        isInstalled = true
    }

    private static func swizzleProtocolClassesGetter() {
        // __NSCFURLSessionConfiguration is the private concrete class backing all
        // URLSessionConfiguration instances.  Fall back to the abstract base if the
        // private name changes in a future OS release.
        let configClass: AnyClass =
            NSClassFromString("__NSCFURLSessionConfiguration")
            ?? NSClassFromString("NSURLSessionConfiguration")
            ?? URLSessionConfiguration.self

        let origSel   = NSSelectorFromString("protocolClasses")
        let swizzSel  = NSSelectorFromString("ik_protocolClasses")

        // The replacement implementation lives on URLSessionConfiguration (abstract base)
        // so that Swift can find it via class_getInstanceMethod.
        guard let newMethod = class_getInstanceMethod(URLSessionConfiguration.self, swizzSel) else {
            print("[InspectKit] ⚠️ ik_protocolClasses method not found — interception unavailable")
            return
        }

        // Copy the replacement onto the concrete class (it lives on the abstract base,
        // and the concrete class is a different class object).
        class_addMethod(
            configClass,
            swizzSel,
            method_getImplementation(newMethod),
            method_getTypeEncoding(newMethod)
        )

        guard
            let origMethod  = class_getInstanceMethod(configClass, origSel),
            let addedMethod = class_getInstanceMethod(configClass, swizzSel)
        else {
            print("[InspectKit] ⚠️ Could not resolve methods for protocolClasses swizzle")
            return
        }

        method_exchangeImplementations(origMethod, addedMethod)
        print("[InspectKit] ✓ protocolClasses swizzle active — all URLSessions will be intercepted")
    }
}

// MARK: - Replacement getter

extension URLSessionConfiguration {
    /// Swizzled replacement for the `protocolClasses` getter.
    ///
    /// After `method_exchangeImplementations`, calling `self.ik_protocolClasses()` invokes
    /// the **original** getter (implementations are swapped), then we prepend
    /// `InspectKitURLProtocol` at index 0 so it runs before the system `_NSURLHTTPProtocol`
    /// which would otherwise claim all http/https and bypass `canInit` entirely.
    @objc func ik_protocolClasses() -> [AnyClass]? {
        // self.ik_protocolClasses() calls the original getter (swapped)
        let original: [AnyClass] = self.ik_protocolClasses() ?? []

        guard InspectKitURLProtocol.isActive else { return original }

        // Avoid duplicates (e.g. when called on the internal forwarding session)
        if original.contains(where: { $0 == InspectKitURLProtocol.self }) {
            return original
        }

        // Prepend FIRST — must run before _NSURLHTTPProtocol which would otherwise
        // claim all http/https and prevent canInit from ever being called.
        // Re-entry is prevented by InspectKitRequestMarker.isHandled on forwarded requests.
        return [InspectKitURLProtocol.self] + original
    }
}
