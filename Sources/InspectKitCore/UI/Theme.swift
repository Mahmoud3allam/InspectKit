import Foundation

#if canImport(UIKit)
import SwiftUI
import UIKit

/// Shared visual tokens for InspectKit and InspectKitMock UIs. Professional dark theme.
public enum NIColor {
    public static let bg = Color(red: 0.051, green: 0.051, blue: 0.078)
    public static let surface = Color(red: 0.075, green: 0.075, blue: 0.118)
    public static let surfaceElevated = Color(red: 0.095, green: 0.095, blue: 0.150)
    public static let divider = Color.white.opacity(0.08)
    public static let text = Color.white
    public static let textMuted = Color.white.opacity(0.55)
    public static let textFaint = Color.white.opacity(0.25)
    public static let accent = Color(red: 0.133, green: 0.400, blue: 1.000)
    public static let accentCyan = Color(red: 0.000, green: 0.800, blue: 1.000)
    public static let success = Color(red: 0.22, green: 0.78, blue: 0.45)
    public static let warning = Color(red: 0.98, green: 0.74, blue: 0.18)
    public static let failure = Color(red: 0.98, green: 0.36, blue: 0.39)
    public static let pending = Color(red: 0.55, green: 0.62, blue: 0.75)

    public static func method(_ m: HTTPMethod) -> Color {
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

    public static func statusColor(_ code: Int?) -> Color {
        guard let code else { return pending }
        switch code {
        case 100..<300: return success
        case 300..<400: return warning
        default: return failure
        }
    }
}

public enum NIFont {
    public static let mono          = Font.system(.footnote, design: .monospaced)
    public static let monoSemibold  = Font.system(size: 12, weight: .semibold, design: .monospaced)
    public static let monoSmall     = Font.system(.caption, design: .monospaced)
    public static let badge         = Font.system(size: 11, weight: .bold, design: .rounded)
    public static let sectionTitle  = Font.system(size: 15, weight: .semibold, design: .rounded)
    public static let footnoteSemibold = Font.system(size: 13, weight: .semibold)
    public static let title3Semibold   = Font.system(size: 20, weight: .semibold, design: .rounded)
}

public extension View {
    @ViewBuilder
    func enableTextSelection() -> some View {
        if #available(iOS 15, *) {
            self.textSelection(.enabled)
        } else {
            self
        }
    }
}

/// iOS 13-compatible spinner.
public struct NIActivityIndicator: UIViewRepresentable {
    public init() {}
    public func makeUIView(context: Context) -> UIActivityIndicatorView {
        let v = UIActivityIndicatorView(style: .medium)
        v.startAnimating()
        return v
    }
    public func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}

#endif // canImport(UIKit)
