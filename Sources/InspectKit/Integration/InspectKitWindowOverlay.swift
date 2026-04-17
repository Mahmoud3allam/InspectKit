import UIKit
import SwiftUI

/// A UIWindow-based floating overlay that works in any UIKit application —
/// including pure UIKit, UIKit+SceneDelegate, and mixed UIKit+SwiftUI setups.
///
/// The window sits above all other windows and uses `PassthroughWindow` so that
/// only touches on the inspector bubble itself are captured; everything else
/// falls through to your app's content.
///
/// Usage (AppDelegate):
/// ```swift
/// InspectKitWindowOverlay.shared.install(in: window)
/// ```
///
/// Usage (SceneDelegate):
/// ```swift
/// InspectKitWindowOverlay.shared.install(in: scene)
/// ```
public final class InspectKitWindowOverlay {
    public static let shared = InspectKitWindowOverlay()

    private var overlayWindow: PassthroughWindow?
    private var hostingController: UIHostingController<AnyView>?
    private var customIcon: UIImage?
    private var imageContentMode: ContentMode = .fit
    private var bubbleColor: Color?

    private init() {}

    // MARK: - Install (UIWindow — AppDelegate style)

    /// Installs the floating bubble into a new window above `sibling`.
    /// Call this once from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// - Parameters:
    ///   - customIcon: Optional image rendered inside the bubble. `nil` = default "network" SF Symbol.
    ///   - imageContentMode: How the custom icon is scaled in its frame. Default `.fit`.
    ///   - bubbleColor: Background colour of the bubble. `nil` = default accent gradient.
    @MainActor
    public func install(in sibling: UIWindow,
                        customIcon: UIImage? = nil,
                        imageContentMode: ContentMode = .fit,
                        bubbleColor: Color? = nil) {
        guard InspectKit.shared.configuration.isEnabled,
              InspectKit.shared.configuration.showsFloatingOverlay else { return }
        guard overlayWindow == nil else { return }

        self.customIcon = customIcon
        self.imageContentMode = imageContentMode
        self.bubbleColor = bubbleColor

        let window = PassthroughWindow(frame: sibling.bounds)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isHidden = false

        let hosting = UIHostingController(rootView: AnyView(overlayContent))
        hosting.view.backgroundColor = .clear
        hosting.view.frame = window.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        // Restore the app window as key so keyboard/text input isn't disrupted.
        sibling.makeKeyAndVisible()

        overlayWindow = window
        hostingController = hosting
    }

    // MARK: - Install (UIWindowScene — SceneDelegate style)

    /// Installs the floating bubble into a dedicated window in `scene`.
    /// Call this from `SceneDelegate.scene(_:willConnectTo:options:)`.
    ///
    /// - Parameters:
    ///   - customIcon: Optional image rendered inside the bubble. `nil` = default "network" SF Symbol.
    ///   - imageContentMode: How the custom icon is scaled in its frame. Default `.fit`.
    ///   - bubbleColor: Background colour of the bubble. `nil` = default accent gradient.
    @MainActor
    public func install(in scene: UIWindowScene,
                        customIcon: UIImage? = nil,
                        imageContentMode: ContentMode = .fit,
                        bubbleColor: Color? = nil) {
        guard InspectKit.shared.configuration.isEnabled,
              InspectKit.shared.configuration.showsFloatingOverlay else { return }
        guard overlayWindow == nil else { return }

        self.customIcon = customIcon
        self.imageContentMode = imageContentMode
        self.bubbleColor = bubbleColor

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear

        let hosting = UIHostingController(rootView: AnyView(overlayContent))
        hosting.view.backgroundColor = .clear
        window.rootViewController = hosting
        window.makeKeyAndVisible()

        // Re-key the scene's existing windows so the inspector window doesn't
        // steal first-responder status from the app.
        scene.windows.first(where: { $0 !== window })?.makeKeyAndVisible()

        overlayWindow = window
        hostingController = hosting
    }

    // MARK: - Remove

    @MainActor
    public func remove() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        hostingController = nil
        customIcon = nil
        imageContentMode = .fit
        bubbleColor = nil
    }

    // MARK: - Private

    private var overlayContent: some View {
        InspectKitOverlay(customIcon: customIcon,
                          imageContentMode: imageContentMode,
                          bubbleColor: bubbleColor)
    }
}

// MARK: - PassthroughWindow

/// A UIWindow that only consumes touches that land inside the bubble.
///
/// We cannot rely on `super.hitTest` to distinguish bubble vs transparent areas because
/// `UIHostingController` renders SwiftUI content into a single `_UIHostingView` — there
/// may be no separate UIKit subviews for individual SwiftUI elements. In that case
/// `super.hitTest` always returns the root hosting view, and the old "== rootVC.view"
/// check would pass EVERY touch through, including taps on the bubble itself.
///
/// Instead we do explicit geometry: only claim touches within the bubble's tracked rect.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard InspectKitBubbleTracker.shared.contains(point) else { return nil }
        // Touch is in the bubble — let UIKit (and SwiftUI) handle it normally.
        return super.hitTest(point, with: event) ?? rootViewController?.view
    }
}

// MARK: - InspectKitBubbleTracker

/// Lightweight singleton that tracks the bubble's current screen centre so that
/// `PassthroughWindow` can do a geometry-based hit test instead of relying on the
/// UIKit view hierarchy produced by UIHostingController.
final class InspectKitBubbleTracker {
    static let shared = InspectKitBubbleTracker()
    private init() {}

    /// Centre of the bubble in window/screen coordinates. Updated by InspectKitOverlay.
    var center: CGPoint = CGPoint(x: 160, y: 320)

    /// When the dashboard sheet is open the overlay window owns the full screen,
    /// so all touches must be captured — not just the bubble area.
    var isDashboardOpen: Bool = false

    /// Capture radius — half the bubble width (26) plus 8 pt generous padding.
    private let hitRadius: CGFloat = 34

    /// Returns true if `point` falls within the bubble's hit area,
    /// or always true while the dashboard sheet is presented.
    func contains(_ point: CGPoint) -> Bool {
        if isDashboardOpen { return true }
        let dx = point.x - center.x
        let dy = point.y - center.y
        return dx * dx + dy * dy <= hitRadius * hitRadius
    }
}
