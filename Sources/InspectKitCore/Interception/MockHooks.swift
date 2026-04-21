import Foundation

/// Weak coupling hook between InspectKitMock and InspectKit.
///
/// InspectKit installs `onHit` in its `start()`. InspectKitMock calls `onHit?(record)`
/// after synthesising a mocked response so the Inspector dashboard also shows the request.
/// If InspectKit is not linked or not started, the closure is nil and the call is a no-op.
public enum MockHooks {
    public static var onHit: ((NetworkRequestRecord) -> Void)?
}
