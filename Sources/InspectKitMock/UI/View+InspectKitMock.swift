#if canImport(UIKit)
import SwiftUI
import InspectKitCore

public extension View {
    /// Attaches the InspectKitMock dashboard as a gesture-triggered sheet.
    /// Shake the device or call `InspectKitMock.shared.presentDashboard()` to open.
    func inspectKitMock(store: MockStore? = nil) -> some View {
        self.modifier(InspectKitMockModifier(store: store ?? InspectKitMock.shared.store))
    }
}

private struct InspectKitMockModifier: ViewModifier {
    let store: MockStore
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                MockDashboardView(store: store, onDismiss: { isPresented = false })
            }
            // Expose a notification-based trigger so other parts of the app can open the sheet.
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("InspectKitMock.PresentDashboard"))) { _ in
                isPresented = true
            }
    }
}

public extension InspectKitMock {
    /// Opens the mock dashboard programmatically (e.g. from a shake gesture).
    /// Use this when the `.inspectKitMock()` SwiftUI modifier is attached to your root view.
    func presentDashboard() {
        NotificationCenter.default.post(name: Notification.Name("InspectKitMock.PresentDashboard"),
                                        object: nil)
    }

    /// Presents the mock dashboard from a UIViewController (UIKit apps).
    /// Creates a UIHostingController wrapping MockDashboardView and presents it modally.
    func presentDashboard(from viewController: UIViewController) {
        let dashboard = MockDashboardView(store: store) {
            viewController.presentedViewController?.dismiss(animated: true)
        }
        let host = UIHostingController(rootView: dashboard)
        host.modalPresentationStyle = .fullScreen
        viewController.present(host, animated: true)
    }
}

#endif // canImport(UIKit)
