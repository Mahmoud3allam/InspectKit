import Foundation

extension ByteCountFormatter {
    static let networkInspector: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    static func string(fromBytes bytes: Int) -> String {
        networkInspector.string(fromByteCount: Int64(max(bytes, 0)))
    }
}
