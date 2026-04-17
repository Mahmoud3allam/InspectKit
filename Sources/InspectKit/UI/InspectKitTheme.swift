import SwiftUI
import UIKit

/// Shared visual tokens for the inspector UI. Professional dark theme.
enum NIColor {
    static let bg = Color(red: 0.051, green: 0.051, blue: 0.078)
    static let surface = Color(red: 0.075, green: 0.075, blue: 0.118)
    static let surfaceElevated = Color(red: 0.095, green: 0.095, blue: 0.150)
    static let divider = Color.white.opacity(0.08)
    static let text = Color.white
    static let textMuted = Color.white.opacity(0.55)
    static let textFaint = Color.white.opacity(0.25)
    static let accent = Color(red: 0.133, green: 0.400, blue: 1.000)
    static let accentCyan = Color(red: 0.000, green: 0.800, blue: 1.000)
    static let success = Color(red: 0.22, green: 0.78, blue: 0.45)
    static let warning = Color(red: 0.98, green: 0.74, blue: 0.18)
    static let failure = Color(red: 0.98, green: 0.36, blue: 0.39)
    static let pending = Color(red: 0.55, green: 0.62, blue: 0.75)

    static func method(_ m: HTTPMethod) -> Color {
        switch m {
        case .GET: return Color(red: 0.26, green: 0.70, blue: 0.96)
        case .POST: return Color(red: 0.36, green: 0.78, blue: 0.48)
        case .PUT: return Color(red: 0.95, green: 0.70, blue: 0.22)
        case .PATCH: return Color(red: 0.85, green: 0.56, blue: 0.92)
        case .DELETE: return Color(red: 0.95, green: 0.38, blue: 0.39)
        case .HEAD, .OPTIONS, .TRACE, .CONNECT, .OTHER:
            return Color(red: 0.55, green: 0.62, blue: 0.75)
        }
    }

    static func statusColor(_ code: Int?) -> Color {
        guard let code else { return pending }
        switch code {
        case 100..<300: return success
        case 300..<400: return warning
        default: return failure
        }
    }
}

// Font.weight(_:) is iOS 14+, so every weight variant is a separate token
// using Font.system(size:weight:design:) which is iOS 13+.
enum NIFont {
    static let mono         = Font.system(.footnote, design: .monospaced)
    static let monoSemibold = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let monoSmall    = Font.system(.caption, design: .monospaced)
    static let badge        = Font.system(size: 11, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
    /// Replaces `.footnote.weight(.semibold)` — Font.weight is iOS 14+
    static let footnoteSemibold = Font.system(size: 13, weight: .semibold)
    /// Replaces `.system(.title3, design: .rounded).weight(.semibold)`
    static let title3Semibold = Font.system(size: 20, weight: .semibold, design: .rounded)
}

// MARK: - iOS 13 compatibility helpers

extension View {
    /// `.textSelection(.enabled)` requires iOS 15; this wrapper is a no-op below that.
    @ViewBuilder
    func enableTextSelection() -> some View {
        if #available(iOS 15, *) {
            self.textSelection(.enabled)
        } else {
            self
        }
    }
}

/// iOS 13-compatible spinner. Replaces `ProgressView().progressViewStyle(.circular)`
/// which requires iOS 14.
struct NIActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let v = UIActivityIndicatorView(style: .medium)
        v.startAnimating()
        return v
    }
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}
