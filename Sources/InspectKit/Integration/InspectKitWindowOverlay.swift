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

    private init() {}

    // MARK: - Install (UIWindow — AppDelegate style)

    /// Installs the floating bubble into a new window above `sibling`.
    /// Call this once from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// - Parameter customIcon: Optional image rendered inside the bubble.
    ///   Pass `nil` to use the default "network" SF Symbol.
    @MainActor
    public func install(in sibling: UIWindow, customIcon: UIImage? = nil) {
        guard InspectKit.shared.configuration.isEnabled,
              InspectKit.shared.configuration.showsFloatingOverlay else { return }
        guard overlayWindow == nil else { return }

        self.customIcon = customIcon

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
    /// - Parameter customIcon: Optional image rendered inside the bubble.
    ///   Pass `nil` to use the default "network" SF Symbol.
    @MainActor
    public func install(in scene: UIWindowScene, customIcon: UIImage? = nil) {
        guard InspectKit.shared.configuration.isEnabled,
              InspectKit.shared.configuration.showsFloatingOverlay else { return }
        guard overlayWindow == nil else { return }

        self.customIcon = customIcon

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
    }

    // MARK: - Private

    private var overlayContent: some View {
        InspectKitOverlay(customIcon: customIcon)
    }
}

// MARK: - PassthroughWindow

/// A UIWindow that only consumes touches that land on a real view.
/// Touches on transparent areas fall through to the window below.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        // If the hit view is the root hosting controller's view (clear background),
        // pass the touch through so the underlying window handles it.
        return hit == rootViewController?.view ? nil : hit
    }
}
