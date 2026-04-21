import Foundation

public struct MockResponse: Codable, Sendable, Equatable {

    public enum Body: Codable, Sendable, Equatable {
        case none
        case data(Data)
        case text(String)
        case json(String)                           // raw JSON string
        case bundleFile(name: String, ext: String)  // loaded from Bundle.main at delivery time

        func resolve() -> Data {
            switch self {
            case .none:
                return Data()
            case .data(let d):
                return d
            case .text(let s):
                return s.data(using: .utf8) ?? Data()
            case .json(let s):
                return s.data(using: .utf8) ?? Data()
            case .bundleFile(let name, let ext):
                guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                      let data = try? Data(contentsOf: url) else { return Data() }
                return data
            }
        }
    }

    public enum Kind: Codable, Sendable, Equatable {
        case ok(statusCode: Int, headers: [String: String], body: Body)
        case failure(domain: String, code: Int, userInfo: [String: String])
    }

    public var kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}
