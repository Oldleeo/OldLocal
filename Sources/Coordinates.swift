import Foundation

struct Coordinates: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    static func parse(_ input: String) -> Coordinates? {
        let parts = input.replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "−", with: "-")
            .split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
              lat.isFinite, lon.isFinite,
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return Coordinates(latitude: lat, longitude: lon)
    }

    var text: String {
        String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude)
    }
}

struct Favorite: Codable, Equatable {
    let id: UUID
    var note: String
    var coordinates: Coordinates
    var group: String
    init(id: UUID, note: String, coordinates: Coordinates, group: String = "未分组") {
        self.id = id; self.note = note; self.coordinates = coordinates
        self.group = Self.normalizedGroup(group)
    }
    static func normalizedGroup(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "未分组" : clean
    }
    enum CodingKeys: String, CodingKey { case id, note, coordinates, group }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        note = try values.decode(String.self, forKey: .note)
        coordinates = try values.decode(Coordinates.self, forKey: .coordinates)
        group = Self.normalizedGroup(try values.decodeIfPresent(String.self, forKey: .group) ?? "未分组")
    }
}

enum FavoriteOrdering {
    static func moving(_ items: [Favorite], id: UUID, before target: UUID?, after last: UUID? = nil) -> [Favorite] {
        guard let source = items.firstIndex(where: { $0.id == id }), target != id else { return items }
        var result = items
        let item = result.remove(at: source)
        if let target = target, let index = result.firstIndex(where: { $0.id == target }) { result.insert(item, at: index) }
        else if let last = last, let index = result.firstIndex(where: { $0.id == last }) { result.insert(item, at: index + 1) }
        else { result.append(item) }
        return result
    }
}

struct FavoritesStore {
    let url: URL

    static func local() -> FavoritesStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("art.oldlee.maclocation", isDirectory: true)
        return FavoritesStore(url: directory.appendingPathComponent("favorites.json"))
    }

    func load() throws -> [Favorite] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let items = try JSONDecoder().decode([Favorite].self, from: Data(contentsOf: url))
        guard Set(items.map(\.id)).count == items.count,
              items.allSatisfy({ !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.coordinates.latitude.isFinite && $0.coordinates.longitude.isFinite &&
                  (-90...90).contains($0.coordinates.latitude) &&
                  (-180...180).contains($0.coordinates.longitude) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return items
    }

    var trash: FavoritesStore { FavoritesStore(url: url.deletingLastPathComponent().appendingPathComponent("recently-deleted.json")) }
    func moveToTrash(_ item: Favorite, from items: [Favorite]) throws -> [Favorite] {
        var deleted = try trash.load().filter { $0.id != item.id }
        deleted.append(item)
        try trash.save(deleted)
        let remaining = items.filter { $0.id != item.id }
        try save(remaining)
        return remaining
    }
    func restoring(_ item: Favorite, into items: [Favorite]) throws -> [Favorite] {
        let restored = items.contains(where: { $0.id == item.id }) ? items : items + [item]
        try save(restored)
        try trash.save(try trash.load().filter { $0.id != item.id })
        return restored
    }

    func save(_ items: [Favorite]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: url, options: .atomic)
    }
}
