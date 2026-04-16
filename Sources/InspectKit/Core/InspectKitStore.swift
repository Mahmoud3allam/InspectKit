import Foundation
import Combine

@MainActor
public final class InspectKitStore: ObservableObject {
    @Published public private(set) var records: [NetworkRequestRecord] = []

    private var indexByID: [UUID: Int] = [:]
    private var sequenceCounter: Int = 0
    private let maxRetained: Int
    private let persistence: InspectKitPersistence?

    public init(configuration: InspectKitConfiguration) {
        self.maxRetained = max(configuration.maxStoredRequests, 10)
        self.persistence = configuration.persistToDisk
            ? InspectKitPersistence(fileName: configuration.persistenceFileName)
            : nil
        if let loaded = persistence?.load() {
            self.records = loaded
            self.sequenceCounter = loaded.map(\.sequence).max() ?? 0
            rebuildIndex()
        }
    }

    public func nextSequence() -> Int {
        sequenceCounter += 1
        return sequenceCounter
    }

    public func insert(_ record: NetworkRequestRecord) {
        records.insert(record, at: 0)
        rebuildIndex()
        trimIfNeeded()
        schedulePersist()
    }

    public func update(_ record: NetworkRequestRecord) {
        if let idx = indexByID[record.id] {
            records[idx] = record
        } else {
            records.insert(record, at: 0)
            rebuildIndex()
        }
        schedulePersist()
    }

    public func mutate(id: UUID, _ mutation: (inout NetworkRequestRecord) -> Void) {
        guard let idx = indexByID[id] else { return }
        var r = records[idx]
        mutation(&r)
        records[idx] = r
        schedulePersist()
    }

    public func record(for id: UUID) -> NetworkRequestRecord? {
        guard let idx = indexByID[id] else { return nil }
        return records[idx]
    }

    public func clear() {
        records.removeAll()
        indexByID.removeAll()
        schedulePersist()
    }

    // MARK: - Filtering helpers

    public enum StateFilter: String, CaseIterable, Identifiable {
        case all, success, failed, inProgress
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .all: return "All"
            case .success: return "Success"
            case .failed: return "Failed"
            case .inProgress: return "Active"
            }
        }
    }

    public func filtered(query: String,
                         stateFilter: StateFilter,
                         methodFilter: Set<HTTPMethod>) -> [NetworkRequestRecord] {
        records.filter { r in
            if !methodFilter.isEmpty && !methodFilter.contains(r.method) { return false }
            switch stateFilter {
            case .all: break
            case .success: if !r.isSuccess { return false }
            case .failed: if !r.isFailure { return false }
            case .inProgress: if r.state != .inProgress { return false }
            }
            if query.isEmpty { return true }
            let q = query.lowercased()
            if r.urlString.lowercased().contains(q) { return true }
            if r.path.lowercased().contains(q) { return true }
            if r.host?.lowercased().contains(q) == true { return true }
            if "\(r.statusCode ?? 0)".contains(q) { return true }
            return false
        }
    }

    public var totalCount: Int { records.count }
    public var failureCount: Int { records.filter(\.isFailure).count }
    public var activeCount: Int { records.filter { $0.state == .inProgress }.count }

    public var averageDurationMS: Double {
        let durations = records.compactMap(\.durationMS)
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }

    // MARK: - Internal

    private func rebuildIndex() {
        indexByID.removeAll(keepingCapacity: true)
        for (i, r) in records.enumerated() { indexByID[r.id] = i }
    }

    private func trimIfNeeded() {
        if records.count > maxRetained {
            records.removeLast(records.count - maxRetained)
            rebuildIndex()
        }
    }

    private var persistTask: Task<Void, Never>?
    private func schedulePersist() {
        guard let persistence else { return }
        persistTask?.cancel()
        let snapshot = records
        persistTask = Task.detached(priority: .background) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            persistence.save(snapshot)
        }
    }
}

// MARK: - Persistence

final class InspectKitPersistence {
    private let url: URL

    init?(fileName: String) {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        self.url = dir.appendingPathComponent(fileName)
    }

    func load() -> [NetworkRequestRecord]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.networkInspector.decode([NetworkRequestRecord].self, from: data)
    }

    func save(_ records: [NetworkRequestRecord]) {
        do {
            let data = try JSONEncoder.networkInspector.encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            // best-effort persistence
        }
    }
}

extension JSONEncoder {
    static let networkInspector: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.dataEncodingStrategy = .base64
        return e
    }()
}

extension JSONDecoder {
    static let networkInspector: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.dataDecodingStrategy = .base64
        return d
    }()
}
