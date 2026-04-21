import Foundation
import InspectKitCore

/// Registers InspectKitMockURLProtocol at priority 200 (higher than InspectKit's 100),
/// so Mock intercepts matching requests before the Inspector does.
enum MockAutoCapture {
    static func install() {
        CoreAutoCapture.register(InspectKitMockURLProtocol.self, priority: 200)
    }
}
