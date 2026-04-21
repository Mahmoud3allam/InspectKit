import Foundation
import ObjectiveC

/// Shared URLSessionConfiguration swizzle used by both InspectKit and InspectKitMock.
///
/// Frameworks register their URLProtocol class with a priority; higher priority classes
/// appear first in `protocolClasses` so they get first crack at `canInit`. A single
/// swizzle is installed on first `register` call; subsequent registrations just update
/// the sorted class list.
public enum CoreAutoCapture {
    private static let lock = NSLock()
    private static var _isInstalled = false
    private static var _entries: [(priority: Int, cls: AnyClass)] = []

    /// Register a URLProtocol class. Higher `priority` = earlier in the protocol list.
    /// - InspectKit uses priority 100
    /// - InspectKitMock uses priority 200 so Mock runs before Inspector
    public static func register(_ cls: AnyClass, priority: Int) {
        lock.lock()
        _entries.removeAll { $0.cls == cls }
        _entries.append((priority: priority, cls: cls))
        _entries.sort { $0.priority > $1.priority }
        let needsInstall = !_isInstalled
        if needsInstall { _isInstalled = true }
        lock.unlock()

        if needsInstall { installSwizzle() }
    }

    public static func unregister(_ cls: AnyClass) {
        lock.lock()
        _entries.removeAll { $0.cls == cls }
        lock.unlock()
    }

    static func injectedClasses() -> [AnyClass] {
        lock.lock()
        defer { lock.unlock() }
        return _entries.map { $0.cls }
    }

    private static func installSwizzle() {
        let configClass: AnyClass =
            NSClassFromString("__NSCFURLSessionConfiguration")
            ?? NSClassFromString("NSURLSessionConfiguration")
            ?? URLSessionConfiguration.self

        let origSel = NSSelectorFromString("protocolClasses")
        let swizzSel = NSSelectorFromString("ik_core_protocolClasses")

        guard let newMethod = class_getInstanceMethod(URLSessionConfiguration.self, swizzSel) else {
            return
        }
        class_addMethod(configClass, swizzSel,
                        method_getImplementation(newMethod),
                        method_getTypeEncoding(newMethod))
        guard let origMethod  = class_getInstanceMethod(configClass, origSel),
              let addedMethod = class_getInstanceMethod(configClass, swizzSel) else { return }
        method_exchangeImplementations(origMethod, addedMethod)
    }
}

// MARK: - Swizzled getter

extension URLSessionConfiguration {
    @objc func ik_core_protocolClasses() -> [AnyClass]? {
        // After swizzle, self.ik_core_protocolClasses() calls the original getter.
        let original: [AnyClass] = self.ik_core_protocolClasses() ?? []
        let toInject = CoreAutoCapture.injectedClasses()
        guard !toInject.isEmpty else { return original }
        // Deduplicate: remove from original any class already in toInject, then prepend.
        let deduped = original.filter { cls in !toInject.contains { $0 == cls } }
        return toInject + deduped
    }
}
