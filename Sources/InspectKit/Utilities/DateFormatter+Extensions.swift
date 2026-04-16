import Foundation

extension DateFormatter {
    static let networkInspectorTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static let networkInspectorFull: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}

extension Double {
    /// Formats a duration expressed in milliseconds.
    func formattedMilliseconds() -> String {
        if self < 1 { return String(format: "%.2f ms", self) }
        if self < 1000 { return String(format: "%.0f ms", self) }
        let s = self / 1000
        if s < 60 { return String(format: "%.2f s", s) }
        let m = Int(s / 60)
        let rem = s.truncatingRemainder(dividingBy: 60)
        return String(format: "%dm %.1fs", m, rem)
    }
}
