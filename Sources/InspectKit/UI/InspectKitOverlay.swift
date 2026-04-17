import SwiftUI

/// A floating, draggable debug bubble that opens the network inspector dashboard.
///
/// Drag smoothness notes:
/// - Uses `@GestureState` instead of `@State` for the live translation so it
///   auto-resets with a spring when the finger lifts — no manual `.zero` reset needed.
/// - `minimumDistance: 0` means tracking starts the instant the finger touches,
///   eliminating the 10-pt jump that the default threshold causes.
/// - Tap vs drag is distinguished in `onEnded` by total travel distance (< 10 pt = tap).
/// - Uses `.position()` to place the bubble directly by its centre point, which is
///   simpler to reason about than stacked `.offset()` values.
public struct InspectKitOverlay: View {

    @ObservedObject private var store: InspectKitStore

    /// Centre of the bubble in the GeometryReader's coordinate space.
    @State private var position: CGPoint = CGPoint(x: 160, y: 320)

    /// Live translation while the finger is down. `@GestureState` resets
    /// automatically to `.zero` (with animation) the moment the gesture ends.
    @GestureState private var dragTranslation: CGSize = .zero

    @State private var showDashboard = false

    /// Optional custom image rendered inside the bubble.
    /// Pass `nil` to use the default "network" SF Symbol.
    private let customIcon: UIImage?

    public init(store: InspectKitStore? = nil, customIcon: UIImage? = nil) {
        self.store = store ?? InspectKit.shared.store
        self.customIcon = customIcon
    }

    public var body: some View {
        GeometryReader { geo in
            bubble
                .position(
                    x: clampedX(position.x + dragTranslation.width, in: geo.size),
                    y: clampedY(position.y + dragTranslation.height, in: geo.size)
                )
                // Animates the GestureState spring-reset on finger lift
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: dragTranslation)
                // Animates the committed position snap to safe bounds
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: position)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        // Updates GestureState in real time — no explicit state management
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // Tap: total travel < 10 pt (dx²+dy² < 100)
                            if dx * dx + dy * dy < 100 {
                                showDashboard = true
                                InspectKitBubbleTracker.shared.isDashboardOpen = true
                            } else {
                                // Drag: commit final position, spring-snap into bounds
                                let newX = clampedX(position.x + dx, in: geo.size)
                                let newY = clampedY(position.y + dy, in: geo.size)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    position.x = newX
                                    position.y = newY
                                }
                                // Keep tracker in sync so PassthroughWindow knows the new location
                                InspectKitBubbleTracker.shared.center = CGPoint(x: newX, y: newY)
                            }
                        }
                )
                .onAppear {
                    // Seed the tracker with the initial position
                    InspectKitBubbleTracker.shared.center = CGPoint(
                        x: clampedX(position.x, in: geo.size),
                        y: clampedY(position.y, in: geo.size)
                    )
                }
        }
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $showDashboard, onDismiss: {
            // Covers both the explicit dismiss button and swipe-to-dismiss.
            InspectKitBubbleTracker.shared.isDashboardOpen = false
        }) {
            InspectKitDashboardView(store: store, onDismiss: { showDashboard = false })
        }
    }

    // MARK: - Bubble

    private var bubble: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [NIColor.accent, NIColor.accent.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)

            // Icon — custom image or default SF Symbol
            if let icon = customIcon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.white)
            } else {
                Image(systemName: "network")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Badge — active requests (orange pulse dot)
            if store.activeCount > 0 {
                Circle()
                    .fill(NIColor.warning)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 18, y: -18)

            // Badge — failure count (red number)
            } else if store.failureCount > 0 {
                Text("\(store.failureCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Circle().fill(NIColor.failure))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 18, y: -18)
            }
        }
    }

    // MARK: - Clamping

    /// Keeps the bubble centre horizontally within the screen, with 8 pt padding.
    private func clampedX(_ x: CGFloat, in size: CGSize) -> CGFloat {
        let half: CGFloat = 34 // half bubble width + padding
        return min(max(x, half), size.width - half)
    }

    /// Keeps the bubble centre vertically within the screen.
    /// Top edge respects the status bar; bottom edge respects the home indicator.
    private func clampedY(_ y: CGFloat, in size: CGSize) -> CGFloat {
        let minY: CGFloat = 60  // below status bar
        let maxY: CGFloat = size.height - 54 // above home indicator
        return min(max(y, minY), maxY)
    }
}
