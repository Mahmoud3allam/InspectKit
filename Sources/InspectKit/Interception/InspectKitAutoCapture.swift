import Foundation
import ObjectiveC

enum InspectKitAutoCapture {
    private static var isInstalled = false

    /// Installs the method swizzle that injects InspectKitURLProtocol
    /// into all URLSessionConfiguration instances created after this call.
    static func install() {
        guard !isInstalled else { return }
        swizzleProtocolClassesGetter()
        isInstalled = true
    }

    private static func swizzleProtocolClassesGetter() {
        // The real backing class for all URLSessionConfiguration instances.
        // Falls back to the abstract base if the private class is unavailable.
        let configClass: AnyClass =
            NSClassFromString("__NSCFURLSessionConfiguration")
            ?? NSClassFromString("NSURLSessionConfiguration")
            ?? URLSessionConfiguration.self

        let origSel = NSSelectorFromString("protocolClasses")
        let newSel  = NSSelectorFromString("ik_protocolClasses")

        // Add our replacement method (defined in the extension below) to the real class.
        guard let newMethod = class_getInstanceMethod(URLSessionConfiguration.self, newSel) else { return }
        class_addMethod(configClass, newSel,
                        method_getImplementation(newMethod),
                        method_getTypeEncoding(newMethod))

        // Swap implementations.
        guard
            let origMethod = class_getInstanceMethod(configClass, origSel),
            let addedMethod = class_getInstanceMethod(configClass, newSel)
        else { return }

        method_exchangeImplementations(origMethod, addedMethod)
    }
}

extension URLSessionConfiguration {
    /// Swizzled replacement for `protocolClasses`.
    ///
    /// After `method_exchangeImplementations`, calling `self.ik_protocolClasses()`
    /// invokes the ORIGINAL `protocolClasses` getter (implementations are swapped).
    ///
    /// InspectKit is appended LAST (not prepended) so all existing URLProtocol subclasses
    /// in the user's project run first, unaffected.
    @objc func ik_protocolClasses() -> [AnyClass] {
        let original = self.ik_protocolClasses()   // calls original getter (swapped)
        guard InspectKitURLProtocol.isActive else { return original }
        guard !original.contains(where: { $0 == InspectKitURLProtocol.self }) else { return original }
        return original + [InspectKitURLProtocol.self]  // append LAST, not prepend
    }
}
