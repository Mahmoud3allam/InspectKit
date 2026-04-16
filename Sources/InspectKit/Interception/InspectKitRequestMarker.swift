import Foundation

/// Tagging helpers that prevent `InspectKitURLProtocol` from intercepting
/// requests that it has already emitted via its internal forwarding session.
enum InspectKitRequestMarker {
    static let propertyKey = "com.networkinspector.handled"
    static let recordIDKey = "com.networkinspector.recordID"

    static func isHandled(_ request: URLRequest) -> Bool {
        URLProtocol.property(forKey: propertyKey, in: request) as? Bool == true
    }

    static func mark(_ request: URLRequest, recordID: UUID? = nil) -> URLRequest {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.setProperty(true, forKey: propertyKey, in: mutable)
        if let recordID {
            URLProtocol.setProperty(recordID.uuidString, forKey: recordIDKey, in: mutable)
        }
        return mutable as URLRequest
    }

    static func recordID(from request: URLRequest) -> UUID? {
        guard let s = URLProtocol.property(forKey: recordIDKey, in: request) as? String else { return nil }
        return UUID(uuidString: s)
    }
}
