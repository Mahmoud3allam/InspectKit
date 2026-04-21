import Foundation
import InspectKitCore

/// Installs InspectKitURLProtocol into every URLSessionConfiguration via the shared
/// CoreAutoCapture swizzle. InspectKit registers at priority 100; InspectKitMock registers
/// at 200 so Mock runs first when both are active.
enum InspectKitAutoCapture {
    static func install() {
        CoreAutoCapture.register(InspectKitURLProtocol.self, priority: 100)
    }
}
