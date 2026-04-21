#if canImport(UIKit)
import UIKit
import SwiftUI

public extension UIViewController {

    /// Presents the Network Inspector dashboard modally.
    ///
    /// Safe to call from any UIViewController. No-ops if the inspector is disabled.
    ///
    /// ```swift
    /// button.addTarget(self, action: #selector(openInspector), for: .touchUpInside)
    ///
    /// @objc func openInspector() {
    ///     presentInspectKit()
    /// }
    /// ```
    @MainActor
    func presentInspectKit(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard InspectKit.shared.configuration.isEnabled else { return }

        let dashboard = InspectKitDashboardView(onDismiss: { [weak self] in
            self?.dismiss(animated: true)
        })
        let hosting = UIHostingController(rootView: dashboard)
        hosting.modalPresentationStyle = .fullScreen
        present(hosting, animated: animated, completion: completion)
    }

    /// Returns a `UIViewController` hosting the Network Inspector dashboard.
    /// Useful when you want to push it onto a navigation stack, or embed it yourself.
    @MainActor
    static func networkInspectorViewController(onDismiss: (() -> Void)? = nil) -> UIViewController {
        let dashboard = InspectKitDashboardView(onDismiss: onDismiss)
        return UIHostingController(rootView: dashboard)
    }
}

// MARK: - UINavigationController convenience

public extension UINavigationController {

    /// Pushes the network inspector dashboard onto the navigation stack.
    @MainActor
    func pushInspectKit(animated: Bool = true) {
        guard InspectKit.shared.configuration.isEnabled else { return }
        let vc = UIViewController.networkInspectorViewController {
            self.popViewController(animated: true)
        }
        pushViewController(vc, animated: animated)
    }
}

#endif // canImport(UIKit)
