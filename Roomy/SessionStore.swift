import Foundation

struct ModeSnapshot: Codable, Equatable {
    var width: Int
    var height: Int
    var pixelWidth: Int
    var pixelHeight: Int
    var refreshRate: Double

    var sizeLabel: String {
        "\(width)×\(height)"
    }
}

enum SessionStore {
    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Roomy", isDirectory: true)
    }

    private static var sessionURL: URL {
        directoryURL.appendingPathComponent("session.json")
    }

    static func load() -> ModeSnapshot? {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: sessionURL)
            return try JSONDecoder().decode(ModeSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ snapshot: ModeSnapshot) {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: sessionURL, options: .atomic)
        } catch {
            // Best-effort persistence for crash recovery.
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: sessionURL)
    }

    static var hasPendingSession: Bool {
        FileManager.default.fileExists(atPath: sessionURL.path)
    }
}
