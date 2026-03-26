import Foundation

/// File-system backed key-value metadata for each terminal surface.
///
/// Layout:  `/tmp/cmux-surfaces/<surface-uuid>/meta.json`
///
/// The directory is created when the surface is born and removed when the
/// surface is closed.  Any process that knows `CMUX_SURFACE_ID` (or
/// `CMUX_SURFACE_META_DIR`) can read/write the file.
enum SurfaceMetaStore {

    // MARK: - Paths

    static let basePath: URL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("cmux-surfaces", isDirectory: true)

    static func metaDirectory(for surfaceId: UUID) -> URL {
        basePath.appendingPathComponent(surfaceId.uuidString, isDirectory: true)
    }

    static func metaFile(for surfaceId: UUID) -> URL {
        metaDirectory(for: surfaceId).appendingPathComponent("meta.json")
    }

    // MARK: - Lifecycle

    /// Create the metadata directory and seed an empty JSON object.
    static func ensureCreated(surfaceId: UUID) {
        let dir = metaDirectory(for: surfaceId)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let file = metaFile(for: surfaceId)
        if !fm.fileExists(atPath: file.path) {
            try? "{}".data(using: .utf8)?.write(to: file)
        }
    }

    /// Remove the metadata directory for a closed surface.
    static func remove(surfaceId: UUID) {
        try? FileManager.default.removeItem(at: metaDirectory(for: surfaceId))
    }

    // MARK: - Read / Write

    /// Read all metadata as a dictionary.
    static func readAll(surfaceId: UUID) -> [String: String] {
        guard let data = try? Data(contentsOf: metaFile(for: surfaceId)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }

    /// Read a single key.
    static func read(surfaceId: UUID, key: String) -> String? {
        readAll(surfaceId: surfaceId)[key]
    }

    /// Set a single key (merge into existing metadata).
    static func set(surfaceId: UUID, key: String, value: String) {
        var dict = readAll(surfaceId: surfaceId)
        dict[key] = value
        write(surfaceId: surfaceId, dict: dict)
    }

    /// Remove a single key.
    static func unset(surfaceId: UUID, key: String) {
        var dict = readAll(surfaceId: surfaceId)
        dict.removeValue(forKey: key)
        write(surfaceId: surfaceId, dict: dict)
    }

    // MARK: - Private

    private static func write(surfaceId: UUID, dict: [String: String]) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.sortedKeys, .prettyPrinted]
        ) else { return }
        try? data.write(to: metaFile(for: surfaceId), options: .atomic)
    }
}
