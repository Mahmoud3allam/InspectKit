import Foundation
import ObjectiveC

enum InspectKitAutoCapture {
    private static var isInstalled = false

    /// Installs swizzles to inject InspectKit into URLSessionConfiguration.default
    /// and URLSessionConfiguration.ephemeral — the two most common entry points.
    static func install() {
        guard !isInstalled else { return }
        swizzleDefaultConfiguration()
        swizzleEphemeralConfiguration()
        isInstalled = true
    }

    private static func swizzleDefaultConfiguration() {
        let cls = URLSessionConfiguration.self
        let selector = #selector(getter: URLSessionConfiguration.default)

        guard let method = class_getClassMethod(cls, selector) else {
            print("[InspectKit] Warning: Could not find URLSessionConfiguration.default")
            return
        }

        let originalImp = method_getImplementation(method)

        let block: @convention(block) () -> URLSessionConfiguration = {
            // Call the original getter
            typealias DefaultGetter = @convention(c) (AnyClass, Selector) -> URLSessionConfiguration
            let getterFunc = unsafeBitCast(originalImp, to: DefaultGetter.self)
            let config = getterFunc(cls, selector)

            // Inject InspectKit into the protocol classes
            guard InspectKitURLProtocol.isActive else { return config }
            var classes = config.protocolClasses ?? []
            if !classes.contains(where: { $0 == InspectKitURLProtocol.self }) {
                classes.append(InspectKitURLProtocol.self)
                config.protocolClasses = classes
            }
            return config
        }

        let newImp = imp_implementationWithBlock(block as Any)
        method_setImplementation(method, newImp)
        print("[InspectKit] ✓ Swizzled URLSessionConfiguration.default")
    }

    private static func swizzleEphemeralConfiguration() {
        let cls = URLSessionConfiguration.self
        let selector = #selector(getter: URLSessionConfiguration.ephemeral)

        guard let method = class_getClassMethod(cls, selector) else {
            print("[InspectKit] Warning: Could not find URLSessionConfiguration.ephemeral")
            return
        }

        let originalImp = method_getImplementation(method)

        let block: @convention(block) () -> URLSessionConfiguration = {
            // Call the original getter
            typealias EphemeralGetter = @convention(c) (AnyClass, Selector) -> URLSessionConfiguration
            let getterFunc = unsafeBitCast(originalImp, to: EphemeralGetter.self)
            let config = getterFunc(cls, selector)

            // Inject InspectKit into the protocol classes
            guard InspectKitURLProtocol.isActive else { return config }
            var classes = config.protocolClasses ?? []
            if !classes.contains(where: { $0 == InspectKitURLProtocol.self }) {
                classes.append(InspectKitURLProtocol.self)
                config.protocolClasses = classes
            }
            return config
        }

        let newImp = imp_implementationWithBlock(block as Any)
        method_setImplementation(method, newImp)
        print("[InspectKit] ✓ Swizzled URLSessionConfiguration.ephemeral")
    }
}
