import SwiftUI

public extension View {
    /// Mounts the floating network inspector overlay on top of this view.
    /// Hidden automatically when the configuration disables the overlay.
    ///
    /// - Parameter customIcon: Image rendered inside the bubble.
    ///   Pass `nil` (default) to use the "network" SF Symbol.
    @ViewBuilder
    func networkInspectorOverlay(customIcon: UIImage? = nil) -> some View {
        if InspectKit.shared.configuration.showsFloatingOverlay,
           InspectKit.shared.configuration.isEnabled {
            self.overlay(InspectKitOverlay(customIcon: customIcon))
        } else {
            self
        }
    }

    /// Presents the inspector dashboard as a sheet when `isPresented` is true.
    func networkInspectorSheet(isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            InspectKitDashboardView(onDismiss: { isPresented.wrappedValue = false })
        }
    }
}
