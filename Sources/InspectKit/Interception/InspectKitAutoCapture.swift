import Foundation
import ObjectiveC

enum InspectKitAutoCapture {
    private static var isInstalled = false

    /// Installs swizzle to inject InspectKit into URLSessionConfiguration.protocolClasses getter
    /// This catches ALL configurations, regardless of how they're created.
    static func install() {
        guard !isInstalled else { return }
        swizzleProtocolClassesGetter()
        isInstalled = true
    }

    private static func swizzleProtocolClassesGetter() {
        // Find the real backing class (varies by iOS version)
        let configClass: AnyClass? =
            NSClassFromString("__NSCFURLSessionConfiguration")
            ?? NSClassFromString("NSURLSessionConfiguration")
            ?? URLSessionConfiguration.self

        guard let cls = configClass else {
            print("[InspectKit] Warning: Could not find URLSessionConfiguration backing class")
            return
        }

        let origSel = NSSelectorFromString("protocolClasses")
        let newSel = NSSelectorFromString("ik_protocolClasses")

        // Add our replacement method to the real class
        guard let newMethod = class_getInstanceMethod(URLSessionConfiguration.self, newSel) else {
            print("[InspectKit] Warning: Could not find ik_protocolClasses method")
            return
        }

        class_addMethod(cls, newSel,
                        method_getImplementation(newMethod),
                        method_getTypeEncoding(newMethod))

        // Exchange implementations (safer than method_setImplementation)
        guard
            let origMethod = class_getInstanceMethod(cls, origSel),
            let addedMethod = class_getInstanceMethod(cls, newSel)
        else {
            print("[InspectKit] Warning: Could not get methods for exchange")
            return
        }

        method_exchangeImplementations(origMethod, addedMethod)
        print("[InspectKit] ✓ Swizzled URLSessionConfiguration.protocolClasses")
    }
}

// MARK: - Swizzled replacement for protocolClasses getter

extension URLSessionConfiguration {
    /// This replaces the original protocolClasses getter.
    /// After method_exchangeImplementations, calling ik_protocolClasses
    /// invokes the ORIGINAL getter (implementations are swapped).
    @objc dynamic var ik_protocolClasses: [AnyClass]? {
        get {
            // Call original getter (implementations are swapped, so this is the original)
            let original = self.ik_protocolClasses
            guard InspectKitURLProtocol.isActive else { return original }
            guard let classes = original else { return [InspectKitURLProtocol.self] }
            guard !classes.contains(where: { $0 == InspectKitURLProtocol.self }) else { return classes }
            // Append InspectKit LAST so existing URLProtocols run first
            return classes + [InspectKitURLProtocol.self]
        }
        set {
            // Forward to original setter (implementations are swapped)
            self.ik_protocolClasses = newValue
        }
    }
}
