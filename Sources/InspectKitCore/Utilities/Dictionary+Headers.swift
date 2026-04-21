import Foundation

public extension Dictionary where Key == String, Value == String {
    func firstValueCaseInsensitive(for key: String) -> String? {
        let lower = key.lowercased()
        for (k, v) in self where k.lowercased() == lower { return v }
        return nil
    }
}
